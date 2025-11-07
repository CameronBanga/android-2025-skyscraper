//
//  TimelineViewModel.swift
//  Skyscraper
//
//  Manages timeline feed state and operations
//

import Foundation
import Combine

// MARK: - Feed Info
struct FeedInfo: Identifiable, Hashable {
    let id: String
    let uri: String?  // nil for "Following" feed
    let displayName: String
    let description: String?
    let avatar: String?

    static let following = FeedInfo(
        id: "following",
        uri: nil,
        displayName: "Following",
        description: "Posts from people you follow",
        avatar: nil
    )
}

@MainActor
class TimelineViewModel: ObservableObject {
    // MARK: - Published State
    @Published var state = TimelineState()

    // MARK: - Services (Dependency Injection)
    private let fetchService: TimelineFetchService
    private let cacheService: TimelineCacheService
    private let refreshService: BackgroundRefreshService
    private let client: ATProtoClient
    private let accountManager: AccountManager
    private let moderationPreferences: ModerationPreferences

    // MARK: - Private State
    private var isBackgroundFetching = false
    private var isStartingBackgroundFetch = false
    private var lastFetchTime: Date?
    private var seenPostURIs: Set<String> = []
    private var newPostURIs: Set<String> = []
    private var isFreshAppLaunch = true
    private var refreshIntervalObserver: NSObjectProtocol?
    private var accountSwitchObserver: NSObjectProtocol?
    private var consecutiveBackgroundFetchFailures = 0
    private static let minimumFetchInterval: TimeInterval = 5.0

    // MARK: - Initialization

    init(
        fetchService: TimelineFetchService? = nil,
        cacheService: TimelineCacheService? = nil,
        refreshService: BackgroundRefreshService? = nil,
        client: ATProtoClient? = nil,
        accountManager: AccountManager? = nil,
        moderationPreferences: ModerationPreferences? = nil
    ) {
        self.fetchService = fetchService ?? DefaultTimelineFetchService()
        self.cacheService = cacheService ?? DefaultTimelineCacheService()
        self.refreshService = refreshService ?? DefaultBackgroundRefreshService()
        self.client = client ?? ATProtoClient.shared
        self.accountManager = accountManager ?? AccountManager.shared
        self.moderationPreferences = moderationPreferences ?? ModerationPreferences.shared

        // Clean up old cached posts on init
        Task {
            self.cacheService.cleanupOldPosts()
            await loadAvailableFeeds()
        }

        // Listen for refresh interval changes
        refreshIntervalObserver = NotificationCenter.default.addObserver(
            forName: .refreshIntervalDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.startBackgroundFetching()
            }
        }

        // Listen for account switches
        accountSwitchObserver = NotificationCenter.default.addObserver(
            forName: .accountDidSwitch,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                AccountLogger.switched(to: self?.client.session?.handle ?? "unknown")
                self?.handleAccountSwitch()
            }
        }
    }

    deinit {
        if let observer = refreshIntervalObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = accountSwitchObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Account Management

    private func handleAccountSwitch() {
        // Stop background fetching
        stopBackgroundFetching()

        // Clear all current data
        state.posts = []
        state.cursor = nil
        state.pendingNewPosts = []
        clearNewPostsTracking()
        state.availableFeeds = []
        state.selectedFeed = nil

        // Reload feeds and timeline for new account
        Task {
            await loadAvailableFeeds()
            await loadTimeline()
            await startBackgroundFetching()
        }
    }

    // MARK: - Background Refresh

    func startBackgroundFetching() async {
        // Guard against overlapping calls - if already starting, skip
        guard !isStartingBackgroundFetch else {
            AppLogger.debug("Skipping startBackgroundFetching - already starting", subsystem: "Feed")
            return
        }

        isStartingBackgroundFetch = true
        defer { isStartingBackgroundFetch = false }

        // Stop any existing background fetch
        stopBackgroundFetching()

        guard let interval = refreshService.getRefreshInterval() else {
            AppLogger.info("Background fetching disabled (set to Never)", subsystem: "Feed")
            return
        }

        AppLogger.info("Starting background fetching (every \(interval) seconds)", subsystem: "Feed")

        await refreshService.startRefreshing(interval: interval) { [weak self] in
            await self?.fetchNewPosts()
        }
    }

    func stopBackgroundFetching() {
        refreshService.stopRefreshing()
        AppLogger.info("Stopped background fetching", subsystem: "Feed")
    }

    private func isUserAtTop() -> Bool {
        guard let visibleURI = state.visiblePostURI, !state.posts.isEmpty else {
            return true
        }

        let topPostURIs = state.posts.prefix(3).map { $0.post.uri }
        return topPostURIs.contains(visibleURI)
    }

    private func fetchNewPosts() async {
        guard !isBackgroundFetching, !state.isLoading, !state.isRefreshing, !state.posts.isEmpty else {
            return
        }

        // Throttle: Don't fetch if we just fetched recently
        if let lastFetch = lastFetchTime, Date().timeIntervalSince(lastFetch) < Self.minimumFetchInterval {
            AppLogger.debug("Skipping fetch - too soon since last fetch (\(Date().timeIntervalSince(lastFetch))s ago)", subsystem: "Feed")
            return
        }

        lastFetchTime = Date()

        isBackgroundFetching = true

        do {
            AppLogger.debug("Background fetch: Attempting to fetch new posts", subsystem: "Feed")

            var allNewPosts: [FeedViewPost] = []
            var fetchCursor: String? = nil
            let currentPostURIs = Set(state.posts.map { $0.post.uri })
            let pendingPostURIs = Set(state.pendingNewPosts.map { $0.post.uri })
            let allExistingURIs = currentPostURIs.union(pendingPostURIs)
            var foundOverlap = false
            var batchCount = 0
            let maxBatches = 10

            while !foundOverlap && batchCount < maxBatches {
                batchCount += 1
                AppLogger.debug("Fetching batch \(batchCount)", subsystem: "Feed")

                let response: FeedResponse
                if let feedURI = state.selectedFeed?.uri {
                    response = try await fetchService.fetchFeed(uri: feedURI, limit: 50, cursor: fetchCursor)
                } else {
                    response = try await fetchService.fetchTimeline(limit: 50, cursor: fetchCursor)
                }

                var newPostsInBatch: [FeedViewPost] = []
                for post in response.feed {
                    if allExistingURIs.contains(post.post.uri) {
                        foundOverlap = true
                        AppLogger.debug("Found overlap at post: \(post.post.uri)", subsystem: "Feed")
                        break
                    } else {
                        newPostsInBatch.append(post)
                    }
                }

                if !newPostsInBatch.isEmpty {
                    allNewPosts.append(contentsOf: newPostsInBatch)
                    AppLogger.debug("Batch \(batchCount): Found \(newPostsInBatch.count) new posts (total: \(allNewPosts.count))", subsystem: "Feed")
                }

                fetchCursor = response.cursor

                if fetchCursor == nil {
                    AppLogger.debug("Reached end of feed (no more cursor)", subsystem: "Feed")
                    break
                }

                if newPostsInBatch.isEmpty {
                    AppLogger.debug("No new posts in batch, stopping", subsystem: "Feed")
                    break
                }
            }

            if batchCount >= maxBatches {
                AppLogger.warning("Hit max batch limit (\(maxBatches) batches, \(allNewPosts.count) posts)", subsystem: "Feed")
            }

            consecutiveBackgroundFetchFailures = 0
            state.backgroundFetchError = nil
            AppLogger.info("Background fetch successful - collected \(allNewPosts.count) new posts from \(batchCount) batches", subsystem: "Feed")

            if !allNewPosts.isEmpty {
                // Filter posts BEFORE adding to pending (removes 'hide' posts, keeps 'warn' and 'show')
                let filteredNewPosts = filterPosts(allNewPosts)
                AppLogger.debug("After moderation filtering: \(filteredNewPosts.count) posts (removed \(allNewPosts.count - filteredNewPosts.count) hidden posts)", subsystem: "Feed")

                if !filteredNewPosts.isEmpty {
                    AppLogger.debug("Storing \(filteredNewPosts.count) new posts for auto-insertion", subsystem: "Feed")

                    state.pendingNewPosts.insert(contentsOf: filteredNewPosts, at: 0)

                    let newURIs = filteredNewPosts.map { $0.post.uri }
                    newPostURIs.formUnion(newURIs)

                    updateUnseenCount()

                    let feedId = feedIdentifier(for: state.selectedFeed)
                    cacheService.cachePosts(filteredNewPosts, feedId: feedId)

                    autoInsertPendingPosts()
                } else {
                    AppLogger.debug("All new posts were filtered by moderation settings", subsystem: "Feed")
                }
            } else {
                AppLogger.debug("No new posts found", subsystem: "Feed")
            }
        } catch {
            consecutiveBackgroundFetchFailures += 1
            AppLogger.error("Background fetch error (\(consecutiveBackgroundFetchFailures) consecutive failures)", error: error, subsystem: "Feed")

            if consecutiveBackgroundFetchFailures >= 10 {
                state.backgroundFetchError = "Timeline updates paused: \(error.localizedDescription)"
                AppLogger.warning("Showing error to user after \(consecutiveBackgroundFetchFailures) failures", subsystem: "Feed")
            }
        }

        isBackgroundFetching = false
    }

    // MARK: - Post Tracking

    func markPostAsSeen(_ postURI: String) {
        if !seenPostURIs.contains(postURI) {
            seenPostURIs.insert(postURI)
            updateUnseenCount()

            // Prune tracking sets when all new posts have been seen
            // This prevents unbounded growth during long sessions
            if state.unseenPostsCount == 0 {
                newPostURIs.subtract(seenPostURIs)
                seenPostURIs.removeAll()
                AppLogger.debug("Pruned tracking sets (all posts seen)", subsystem: "Feed")
            }
        }
    }

    func prefetchImagesForUpcomingPosts(currentPostId: FeedViewPost.ID) {
        guard let currentIndex = state.posts.firstIndex(where: { $0.id == currentPostId }) else {
            return
        }

        let prefetchStartIndex = currentIndex + 1
        let prefetchEndIndex = min(currentIndex + 5, state.posts.count)

        if prefetchStartIndex < state.posts.count {
            let postsToPreload = Array(state.posts[prefetchStartIndex..<prefetchEndIndex])
            cacheService.prefetchImages(for: postsToPreload)
        }
    }

    private func updateUnseenCount() {
        let unseenCount = newPostURIs.subtracting(seenPostURIs).count
        state.unseenPostsCount = unseenCount
        AppLogger.debug("Unseen posts: \(unseenCount)", subsystem: "Feed")
    }

    func clearNewPostsTracking() {
        newPostURIs.removeAll()
        seenPostURIs.removeAll()
        state.unseenPostsCount = 0
        state.pendingNewPosts.removeAll()
    }

    func autoInsertPendingPosts() {
        guard !state.pendingNewPosts.isEmpty else { return }
        FeedLogger.insertingPosts(count: state.pendingNewPosts.count, locked: false)
        state.shouldAutoInsert = true
    }

    func insertPendingPosts() {
        guard !state.pendingNewPosts.isEmpty else { return }

        AppLogger.debug("Attempting to insert \(state.pendingNewPosts.count) pending posts", subsystem: "Feed")

        var seenURIs = Set<String>()
        var dedupedPending: [FeedViewPost] = []
        for post in state.pendingNewPosts {
            if !seenURIs.contains(post.post.uri) {
                dedupedPending.append(post)
                seenURIs.insert(post.post.uri)
            }
        }
        AppLogger.debug("After internal deduplication: \(dedupedPending.count) unique pending posts (removed \(state.pendingNewPosts.count - dedupedPending.count) duplicates)", subsystem: "Feed")

        let currentPostURIs = Set(state.posts.map { $0.post.uri })
        let uniqueNewPosts = dedupedPending.filter { !currentPostURIs.contains($0.post.uri) }

        AppLogger.debug("After timeline deduplication: \(uniqueNewPosts.count) unique posts to insert (removed \(dedupedPending.count - uniqueNewPosts.count) already in timeline)", subsystem: "Feed")

        // Clean up tracking for duplicate posts that won't be inserted
        let dedupedURIs = Set(dedupedPending.map { $0.post.uri })
        let insertedURIs = Set(uniqueNewPosts.map { $0.post.uri })
        let droppedURIs = dedupedURIs.subtracting(insertedURIs)

        if !droppedURIs.isEmpty {
            newPostURIs.subtract(droppedURIs)
            updateUnseenCount()
            AppLogger.debug("Removed \(droppedURIs.count) duplicate URIs from tracking", subsystem: "Feed")
        }

        // No need to filter here - already filtered during background fetch
        if !uniqueNewPosts.isEmpty {
            state.posts.insert(contentsOf: uniqueNewPosts, at: 0)
            AppLogger.info("Successfully inserted \(uniqueNewPosts.count) posts", subsystem: "Feed")
        } else {
            AppLogger.warning("No new posts to insert after deduplication", subsystem: "Feed")
        }

        state.pendingNewPosts.removeAll()
    }

    // MARK: - Feed Management

    func loadAvailableFeeds() async {
        state.isLoadingFeeds = true

        do {
            AppLogger.debug("Loading available feeds for \(client.session?.handle ?? "unknown")", subsystem: "Feed")
            let feeds = try await fetchService.fetchAvailableFeeds()

            // Apply saved feed order
            state.availableFeeds = applySavedFeedOrder(to: feeds)
            FeedLogger.changed(from: nil, to: "Loaded \(feeds.count) feeds")

            if state.selectedFeed == nil {
                state.selectedFeed = .following
            }

        } catch {
            AppLogger.error("Failed to load available feeds", error: error, subsystem: "Feed")
            state.availableFeeds = [.following]
            state.selectedFeed = .following
        }

        state.isLoadingFeeds = false
    }

    private func saveFeedOrder() {
        guard let accountId = accountManager.activeAccountId else {
            AppLogger.warning("No active account - cannot save feed order", subsystem: "Feed")
            return
        }

        let feedIDs = state.availableFeeds.map { $0.id }
        let key = "savedFeedOrder_\(accountId)"
        UserDefaults.standard.set(feedIDs, forKey: key)
        AppLogger.debug("Saved feed order for account \(accountId): \(feedIDs)", subsystem: "Feed")
    }

    private func applySavedFeedOrder(to feeds: [FeedInfo]) -> [FeedInfo] {
        guard let accountId = accountManager.activeAccountId else {
            AppLogger.warning("No active account - using default feed order", subsystem: "Feed")
            return feeds
        }

        let key = "savedFeedOrder_\(accountId)"
        guard let savedOrder = UserDefaults.standard.stringArray(forKey: key) else {
            AppLogger.debug("No saved feed order found for account \(accountId), using default order", subsystem: "Feed")
            return feeds
        }

        AppLogger.debug("Loaded saved feed order for account \(accountId): \(savedOrder)", subsystem: "Feed")

        var orderedFeeds: [FeedInfo] = []

        // Create dictionary safely, handling duplicates by keeping first occurrence
        var feedsDict: [String: FeedInfo] = [:]
        var duplicateCount = 0
        for feed in feeds {
            if feedsDict[feed.id] == nil {
                feedsDict[feed.id] = feed
            } else {
                duplicateCount += 1
            }
        }

        if duplicateCount > 0 {
            AppLogger.warning("Found \(duplicateCount) duplicate feed(s) in API response, keeping first occurrence", subsystem: "Feed")
        }

        for feedID in savedOrder {
            if let feed = feedsDict[feedID] {
                orderedFeeds.append(feed)
                feedsDict.removeValue(forKey: feedID)
            }
        }

        let newFeeds = Array(feedsDict.values).sorted { $0.displayName < $1.displayName }
        if !newFeeds.isEmpty {
            AppLogger.debug("Found \(newFeeds.count) new feeds not in saved order, adding to bottom", subsystem: "Feed")
            orderedFeeds.append(contentsOf: newFeeds)
        }

        return orderedFeeds
    }

    func reorderFeeds(from source: IndexSet, to destination: Int) {
        var reorderedFeeds = state.availableFeeds

        let itemsToMove = source.map { reorderedFeeds[$0] }

        for index in source.sorted().reversed() {
            reorderedFeeds.remove(at: index)
        }

        let adjustedDestination = destination > source.first! ? destination - source.count : destination

        reorderedFeeds.insert(contentsOf: itemsToMove, at: adjustedDestination)

        state.availableFeeds = reorderedFeeds
        saveFeedOrder()
    }

    func unfollowFeeds(at indexSet: IndexSet) async {
        let feedsToUnfollow = indexSet.compactMap { index -> String? in
            guard index < state.availableFeeds.count else { return nil }
            let feed = state.availableFeeds[index]

            guard let uri = feed.uri else {
                AppLogger.warning("Cannot unfollow system feed: \(feed.displayName)", subsystem: "Feed")
                return nil
            }

            return uri
        }

        guard !feedsToUnfollow.isEmpty else {
            AppLogger.warning("No feeds to unfollow", subsystem: "Feed")
            return
        }

        AppLogger.debug("Attempting to unfollow \(feedsToUnfollow.count) feeds", subsystem: "Feed")

        do {
            let preferencesResponse = try await client.getPreferences()

            var updatedPreferences: [Preference] = []
            var foundSavedFeeds = false

            for preference in preferencesResponse.preferences {
                if case .savedFeeds(let savedFeeds) = preference {
                    foundSavedFeeds = true

                    let updatedPinned = savedFeeds.pinned.filter { !feedsToUnfollow.contains($0) }
                    let updatedSaved = savedFeeds.saved.filter { !feedsToUnfollow.contains($0) }

                    AppLogger.debug("Before: \(savedFeeds.saved.count) saved feeds", subsystem: "Feed")
                    AppLogger.debug("After: \(updatedSaved.count) saved feeds", subsystem: "Feed")

                    let updatedSavedFeedsPreference = Preference.savedFeeds(
                        SavedFeedsPref(pinned: updatedPinned, saved: updatedSaved)
                    )
                    updatedPreferences.append(updatedSavedFeedsPreference)
                } else {
                    updatedPreferences.append(preference)
                }
            }

            if !foundSavedFeeds {
                AppLogger.error("No saved feeds preference found", error: nil, subsystem: "Feed")
                return
            }

            try await client.putPreferences(preferences: updatedPreferences)
            AppLogger.info("Successfully unfollowed \(feedsToUnfollow.count) feeds", subsystem: "Feed")

            for index in indexSet.sorted().reversed() {
                if index < state.availableFeeds.count {
                    state.availableFeeds.remove(at: index)
                }
            }
            saveFeedOrder()

            await loadAvailableFeeds()

        } catch {
            AppLogger.error("Failed to unfollow feeds", error: error, subsystem: "Feed")
        }
    }

    func switchToFeed(_ feed: FeedInfo) {
        guard feed.id != state.selectedFeed?.id else { return }

        TimelineAnalytics.logFeedSwitched(feedName: feed.displayName)

        state.selectedFeed = feed
        state.cursor = nil
        state.posts = []
        clearNewPostsTracking()

        Task {
            await loadTimeline()
        }
    }

    private func feedIdentifier(for feed: FeedInfo?) -> String {
        guard let accountId = accountManager.activeAccountId else {
            AppLogger.warning("No active account ID - using default feed identifier", subsystem: "Feed")
            return feed?.uri ?? "following"
        }

        let baseFeedId = feed?.uri ?? "following"
        return "\(accountId)_\(baseFeedId)"
    }

    // MARK: - Timeline Operations

    func loadTimeline() async {
        guard !state.isLoading else { return }

        let startTime = Date()
        let feedId = feedIdentifier(for: state.selectedFeed)

        // Load saved anchor and timestamp
        let savedAnchor = cacheService.loadScrollPosition(forFeed: feedId)
        let savedTimestamp = cacheService.loadLastViewedTimestamp(forFeed: feedId)

        // Load cached posts and display immediately if we have them
        var cachedPosts: [FeedViewPost] = []
        if state.posts.isEmpty {
            cachedPosts = cacheService.loadCachedPosts(feedId: feedId)
            if !cachedPosts.isEmpty {
                let filteredCachedPosts = filterPosts(cachedPosts)
                state.posts = filteredCachedPosts
                AppLogger.debug("Loaded \(cachedPosts.count) posts from cache for feed: \(feedId) (\(filteredCachedPosts.count) after moderation)", subsystem: "Feed")

                // If we have a saved anchor in cache, restore it
                if let anchor = savedAnchor, cachedPosts.contains(where: { $0.post.uri == anchor }) {
                    state.savedScrollAnchor = anchor
                    state.savedAnchorTimestamp = savedTimestamp
                    AppLogger.debug("Found saved anchor in cache: \(anchor)", subsystem: "Feed")
                }

                if isFreshAppLaunch {
                    isFreshAppLaunch = false
                }
            }
        }

        state.isLoading = true
        state.errorMessage = nil

        do {
            // Fetch from network with smart paging to find anchor
            var allFetchedPosts: [FeedViewPost] = []
            var newerPosts: [FeedViewPost] = []
            var anchorFound = false
            var fetchCursor: String? = nil
            var pageCount = 0
            let maxPages = 10
            let maxPosts = 500

            while !anchorFound && pageCount < maxPages && allFetchedPosts.count < maxPosts {
                pageCount += 1

                let response: FeedResponse
                if let feedURI = state.selectedFeed?.uri {
                    response = try await fetchService.fetchFeed(uri: feedURI, limit: 50, cursor: fetchCursor)
                } else {
                    response = try await fetchService.fetchTimeline(limit: 50, cursor: fetchCursor)
                }

                allFetchedPosts.append(contentsOf: response.feed)
                fetchCursor = response.cursor

                // Check if this page contains the anchor
                if let anchor = savedAnchor {
                    if let anchorIndex = response.feed.firstIndex(where: { $0.post.uri == anchor }) {
                        // Found the anchor! Everything before it is "newer"
                        newerPosts.append(contentsOf: response.feed[..<anchorIndex])

                        // The anchor and everything after it goes into main posts
                        let anchorAndOlder = Array(response.feed[anchorIndex...])
                        state.posts = filterPosts(anchorAndOlder)
                        state.savedScrollAnchor = anchor
                        state.savedAnchorTimestamp = savedTimestamp
                        anchorFound = true

                        AppLogger.debug("Found anchor after \(pageCount) pages. \(newerPosts.count) newer posts, \(anchorAndOlder.count) from anchor down", subsystem: "Feed")

                        // Fetch one more older page for buffer
                        if let olderCursor = response.cursor {
                            let olderResponse: FeedResponse
                            if let feedURI = state.selectedFeed?.uri {
                                olderResponse = try await fetchService.fetchFeed(uri: feedURI, limit: 50, cursor: olderCursor)
                            } else {
                                olderResponse = try await fetchService.fetchTimeline(limit: 50, cursor: olderCursor)
                            }
                            state.posts.append(contentsOf: filterPosts(olderResponse.feed))
                            state.cursor = olderResponse.cursor
                            AppLogger.debug("Fetched buffer page: \(olderResponse.feed.count) older posts", subsystem: "Feed")
                        }

                        // Sort by createdAt descending to show fresh content first
                        state.posts.sort { $0.post.createdAt > $1.post.createdAt }

                        break
                    } else {
                        // This whole page is newer than the anchor
                        newerPosts.append(contentsOf: response.feed)
                    }
                } else {
                    // No anchor saved, just load normally
                    state.posts = filterPosts(allFetchedPosts)
                    state.posts = allFetchedPosts.sorted { $0.post.createdAt > $1.post.createdAt }
                    state.cursor = fetchCursor
                    break
                }

                if fetchCursor == nil {
                    AppLogger.debug("Reached end of feed at page \(pageCount)", subsystem: "Feed")
                    break
                }
            }

            // If anchor wasn't found, try timestamp fallback
            if !anchorFound && savedAnchor != nil && savedTimestamp != nil {
                AppLogger.warning("Anchor not found after \(pageCount) pages, trying timestamp fallback", subsystem: "Feed")
                let closestPost = findClosestPostByTimestamp(in: allFetchedPosts, to: savedTimestamp!)

                if let closest = closestPost {
                    AppLogger.debug("Found closest post by timestamp: \(closest.post.uri)", subsystem: "Feed")
                    state.savedScrollAnchor = closest.post.uri
                    state.savedAnchorTimestamp = closest.post.createdAt

                    // Split posts around the closest match
                    if let closestIndex = allFetchedPosts.firstIndex(where: { $0.post.uri == closest.post.uri }) {
                        newerPosts = Array(allFetchedPosts[..<closestIndex])
                        state.posts = filterPosts(Array(allFetchedPosts[closestIndex...]))
                        state.cursor = fetchCursor
                        // Sort by createdAt descending to show fresh content first
                        state.posts.sort { $0.post.createdAt > $1.post.createdAt }
                    }
                } else {
                    // Complete fallback: just show newest
                    AppLogger.error("No suitable anchor found, showing newest posts", error: nil, subsystem: "Feed")
                    state.posts = filterPosts(allFetchedPosts)
                    state.posts = allFetchedPosts.sorted { $0.post.createdAt > $1.post.createdAt }
                    state.cursor = fetchCursor
                    cacheService.clearScrollPosition(forFeed: feedId)
                    state.savedScrollAnchor = nil
                    state.savedAnchorTimestamp = nil
                }
            }

            // Store newer posts as pending and trigger auto-insertion
            // This works for both cold start and live updates, preserving anchor position
            if !newerPosts.isEmpty {
                // Sort newer posts by createdAt descending to show fresh content first
                newerPosts.sort { $0.post.createdAt > $1.post.createdAt }
                state.pendingNewPosts = newerPosts
                state.unseenPostsCount = newerPosts.count

                // Prefetch images for newer posts asynchronously
                Task {
                    await cacheService.prefetchImagesAndWait(for: newerPosts)
                }

                AppLogger.debug("\(newerPosts.count) newer posts available", subsystem: "Feed")

                // Trigger auto-insertion (sets shouldAutoInsert flag for view to handle)
                autoInsertPendingPosts()
            }

            // Cache the fetched posts
            cacheService.cachePosts(state.posts, feedId: feedId)

            let duration = Date().timeIntervalSince(startTime)
            TimelineAnalytics.logTimelineLoadTime(duration: duration, postCount: state.posts.count)
        } catch {
            state.errorMessage = error.localizedDescription
            if state.posts.isEmpty {
                state.posts = cachedPosts
            }
        }

        state.isLoading = false

        // Mark that we're no longer on a fresh app launch
        if isFreshAppLaunch {
            isFreshAppLaunch = false
            AppLogger.info("Cold start complete", subsystem: "Feed")
        }
    }

    private func findClosestPostByTimestamp(in posts: [FeedViewPost], to timestamp: Date) -> FeedViewPost? {
        return posts.min(by: { post1, post2 in
            abs(post1.post.createdAt.timeIntervalSince(timestamp)) < abs(post2.post.createdAt.timeIntervalSince(timestamp))
        })
    }

    func refresh() async {
        state.isRefreshing = true
        state.errorMessage = nil
        state.backgroundFetchError = nil
        consecutiveBackgroundFetchFailures = 0

        if !state.pendingNewPosts.isEmpty {
            AppLogger.debug("Pull-to-refresh: Prefetching images for \(state.pendingNewPosts.count) pending posts before inserting", subsystem: "Feed")
            await cacheService.prefetchImagesAndWait(for: state.pendingNewPosts)
            AppLogger.debug("Pull-to-refresh: Inserting \(state.pendingNewPosts.count) pending posts after image prefetch", subsystem: "Feed")
            insertPendingPosts()
        }

        do {
            let response: FeedResponse
            if let feedURI = state.selectedFeed?.uri {
                response = try await fetchService.fetchFeed(uri: feedURI, limit: 50, cursor: nil)
            } else {
                response = try await fetchService.fetchTimeline(limit: 50, cursor: nil)
            }

            // Sort by createdAt descending to show fresh content first
            let sortedFeed = response.feed.sorted { $0.post.createdAt > $1.post.createdAt }
            state.posts = filterPosts(sortedFeed)
            state.cursor = response.cursor

            state.pendingNewPosts.removeAll()
            clearNewPostsTracking()

            let feedId = feedIdentifier(for: state.selectedFeed)
            cacheService.cachePosts(response.feed, feedId: feedId)

            TimelineAnalytics.logTimelineRefreshed()
            AppLogger.info("Manual refresh successful", subsystem: "Feed")
        } catch {
            state.errorMessage = error.localizedDescription
            AppLogger.error("Manual refresh failed", error: error, subsystem: "Feed")
        }

        state.isRefreshing = false
    }

    func loadMore() async {
        guard let cursor = state.cursor, !state.isLoading else { return }
        state.isLoading = true

        do {
            let response: FeedResponse
            if let feedURI = state.selectedFeed?.uri {
                response = try await fetchService.fetchFeed(uri: feedURI, limit: 50, cursor: cursor)
            } else {
                response = try await fetchService.fetchTimeline(limit: 50, cursor: cursor)
            }

            // Sort fetched posts by createdAt descending to maintain chronological order
            let sortedFeed = response.feed.sorted { $0.post.createdAt > $1.post.createdAt }
            state.posts.append(contentsOf: filterPosts(sortedFeed))
            state.cursor = response.cursor

            let feedId = feedIdentifier(for: state.selectedFeed)
            cacheService.cachePosts(response.feed, feedId: feedId)
        } catch {
            state.errorMessage = error.localizedDescription
        }

        state.isLoading = false
    }

    func saveScrollPosition(postURI: String) {
        let feedId = feedIdentifier(for: state.selectedFeed)

        // Save the anchor URI
        cacheService.saveScrollPosition(postURI: postURI, forFeed: feedId)

        // Find and save the timestamp of the anchor post
        if let anchorPost = state.posts.first(where: { $0.post.uri == postURI }) {
            cacheService.saveLastViewedTimestamp(anchorPost.post.createdAt, forFeed: feedId)
        }
    }

    func persistScrollState() {
        // Save current scroll position if available
        if let visibleURI = state.visiblePostURI {
            saveScrollPosition(postURI: visibleURI)
        }
    }

    // MARK: - Post Actions

    func toggleLike(for post: Post) async {
        guard let postIndex = state.posts.firstIndex(where: { $0.post.uri == post.uri }) else {
            AppLogger.warning("Post not found in timeline for optimistic update", subsystem: "Feed")
            return
        }

        let originalFeedViewPost = state.posts[postIndex]
        let wasLiked = post.viewer?.like != nil

        state.posts[postIndex] = originalFeedViewPost.withToggledLike()

        do {
            if wasLiked {
                try await client.unlikePost(likeUri: post.viewer!.like!)
                AppLogger.info("Successfully unliked post", subsystem: "Feed")
            } else {
                let likeUri = try await client.likePost(uri: post.uri, cid: post.cid)
                AppLogger.info("Successfully liked post, URI: \(likeUri)", subsystem: "Feed")

                // Update the viewer state with the real like URI
                if let currentPostIndex = state.posts.firstIndex(where: { $0.post.uri == post.uri }) {
                    var updatedPost = state.posts[currentPostIndex].post
                    updatedPost.viewer?.like = likeUri
                    state.posts[currentPostIndex] = state.posts[currentPostIndex].withUpdatedPost { _ in updatedPost }
                }
            }
        } catch {
            state.posts[postIndex] = originalFeedViewPost

            state.errorMessage = wasLiked ? "Failed to unlike post: \(error.localizedDescription)" : "Failed to like post: \(error.localizedDescription)"
            AppLogger.error("Like action failed, reverted", error: error, subsystem: "Feed")
        }
    }

    func toggleRepost(for post: Post) async {
        guard let postIndex = state.posts.firstIndex(where: { $0.post.uri == post.uri }) else {
            AppLogger.warning("Post not found in timeline for optimistic update", subsystem: "Feed")
            return
        }

        let originalFeedViewPost = state.posts[postIndex]
        let wasReposted = post.viewer?.repost != nil

        state.posts[postIndex] = originalFeedViewPost.withToggledRepost()

        do {
            if wasReposted {
                try await client.unrepost(repostUri: post.viewer!.repost!)
                AppLogger.info("Successfully unreposted", subsystem: "Feed")
            } else {
                let repostUri = try await client.repost(uri: post.uri, cid: post.cid)
                AppLogger.info("Successfully reposted, URI: \(repostUri)", subsystem: "Feed")

                // Update the viewer state with the real repost URI
                if let currentPostIndex = state.posts.firstIndex(where: { $0.post.uri == post.uri }) {
                    var updatedPost = state.posts[currentPostIndex].post
                    updatedPost.viewer?.repost = repostUri
                    state.posts[currentPostIndex] = state.posts[currentPostIndex].withUpdatedPost { _ in updatedPost }
                }
            }
        } catch {
            state.posts[postIndex] = originalFeedViewPost

            state.errorMessage = wasReposted ? "Failed to unrepost: \(error.localizedDescription)" : "Failed to repost: \(error.localizedDescription)"
            AppLogger.error("Repost action failed, reverted", error: error, subsystem: "Feed")
        }
    }

    // MARK: - Moderation

    /// Filter posts based on moderation settings
    private func filterPosts(_ posts: [FeedViewPost]) -> [FeedViewPost] {
        let settings = moderationPreferences.settings

        return posts.filter { feedPost in
            // First check feed-level filters (reposts, replies, quote posts)
            if feedPost.shouldBeFiltered(settings: settings) {
                return false
            }

            // Then check content moderation (labels, muted words)
            let action = feedPost.moderationAction(settings: settings)
            switch action {
            case .hide:
                return false // Remove from timeline
            case .warn, .allow:
                return true // Keep in timeline (warn will be handled in UI)
            }
        }
    }
}
