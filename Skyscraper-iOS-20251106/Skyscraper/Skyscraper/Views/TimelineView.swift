//
//  TimelineView.swift
//  Skyscraper
//
//  Main timeline feed view with pull-to-refresh and smooth scrolling
//

import SwiftUI
import Combine

struct TimelineView: View {
    @StateObject private var viewModel = TimelineViewModel()
    @EnvironmentObject var theme: AppTheme
    @ObservedObject private var accountManager = AccountManager.shared
    @State private var urlToOpen: URL?
    @State private var profileToShow: String?
    @State private var hashtagToSearch: String?
    @State private var postDetailToShow: String?
    @State private var embeddedPostDetailToShow: String?
    @State private var showContent = false
    @State private var showFeedSelector = false
    #if os(iOS)
    @State private var feedSelectorEditMode: EditMode = .inactive
    #endif
    @State private var showSettings = false
    @State private var showAccountSwitcher = false
    @State private var showModerationSettings = false
    @State private var isTransitioningAccounts = false
    @State private var currentTime = Date() // Updates every minute to refresh timestamps
    @Environment(\.scenePhase) private var scenePhase

    private let timeUpdateTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    @State private var scrollPosition: FeedViewPost.ID?

    var body: some View {
        NavigationStack {
            timelineContent
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    #if os(iOS)
                    ToolbarItem(placement: .navigationBarLeading) {
                        settingsButton
                    }
                    #else
                    ToolbarItem(placement: .automatic) {
                        settingsButton
                    }
                    #endif

                    ToolbarItem(placement: .principal) {
                        feedSelectorButton
                    }

                    #if os(iOS)
                    ToolbarItem(placement: .navigationBarTrailing) {
                        moderationButton
                    }
                    #else
                    ToolbarItem(placement: .automatic) {
                        moderationButton
                    }
                    #endif
                }
                .sheet(item: Binding(
                    get: { urlToOpen.map { URLWrapper(url: $0) } },
                    set: { urlToOpen = $0?.url }
                )) { wrapper in
                    SafariView(url: wrapper.url)
                }
                .sheet(isPresented: $showSettings) {
                    NavigationStack {
                        SettingsView()
                    }
                }
                .sheet(isPresented: $showModerationSettings) {
                    ModerationSettingsView()
                }
                .navigationDestination(item: Binding(
                    get: { profileToShow.map { ProfileWrapper(actor: $0) } },
                    set: { profileToShow = $0?.actor }
                )) { wrapper in
                    ProfileView(actor: wrapper.actor)
                }
                .navigationDestination(item: Binding(
                    get: { hashtagToSearch.map { HashtagWrapper(tag: $0) } },
                    set: { hashtagToSearch = $0?.tag }
                )) { wrapper in
                    HashtagSearchView(hashtag: wrapper.tag)
                }
                .navigationDestination(item: Binding(
                    get: { postDetailToShow.map { URIWrapper(uri: $0) } },
                    set: { postDetailToShow = $0?.uri }
                )) { wrapper in
                    PostDetailView(postURI: wrapper.uri)
                }
                .navigationDestination(item: Binding(
                    get: { embeddedPostDetailToShow.map { URIWrapper(uri: $0) } },
                    set: { embeddedPostDetailToShow = $0?.uri }
                )) { wrapper in
                    PostDetailView(postURI: wrapper.uri)
                }
        }
        .tint(theme.accentColor)
        .overlay {
            // Account transition overlay
            if isTransitioningAccounts {
                ZStack {
                    // Use theme accent color for gradient
                    LinearGradient(
                        colors: [
                            theme.accentColor,
                            theme.accentColor.opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()

                    VStack(spacing: 20) {
                        Image(systemName: "building.2")
                            .font(.system(size: 80))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)

                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.5)
                    }
                }
                .transition(.opacity)
            }
        }
        .task {
            await loadInitialData()
        }
        .onDisappear {
            stopBackgroundFetch()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(oldPhase, newPhase)
        }
        .onReceive(timeUpdateTimer) { _ in
            // Update current time every minute to trigger timestamp refresh
            currentTime = Date()
        }
    }

    // MARK: - Computed Properties

    private var feedSelectorButton: some View {
        Button(action: {
            // Save current scroll position before opening feed selector
            if let uri = viewModel.state.visiblePostURI {
                viewModel.saveScrollPosition(postURI: uri)
                ScrollLogger.saved(uri, context: "before opening feed selector")
            }
            showFeedSelector = true
        }) {
            HStack(spacing: 4) {
                if let selectedFeed = viewModel.state.selectedFeed {
                    Text(selectedFeed.displayName)
                        .font(.headline)
                } else {
                    Text("Timeline")
                        .font(.headline)
                }

                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
        }
        .popover(isPresented: $showFeedSelector) {
            feedSelectorView
                .presentationCompactAdaptation(.popover)
        }
    }

    private var feedSelectorView: some View {
        #if os(iOS)
        FeedSelectorView(
            viewModel: viewModel,
            isPresented: $showFeedSelector,
            editMode: $feedSelectorEditMode
        )
        #else
        FeedSelectorView(
            viewModel: viewModel,
            isPresented: $showFeedSelector
        )
        #endif
    }

    private var settingsButton: some View {
        Image(systemName: "gearshape.fill")
            .foregroundStyle(theme.accentColor)
            .onTapGesture {
                showSettings = true
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                // Only show account switcher if there are multiple accounts
                if accountManager.accounts.count > 1 {
                    showAccountSwitcher = true
                }
            }
            .popover(isPresented: $showAccountSwitcher) {
                accountSwitcherView
                    .presentationCompactAdaptation(.popover)
            }
    }

    private var moderationButton: some View {
        Button(action: {
            showModerationSettings = true
        }) {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundStyle(theme.accentColor)
        }
    }

    private var accountSwitcherView: some View {
        NavigationStack {
            List {
                ForEach(accountManager.accounts) { account in
                    Button(action: {
                        if account.id != accountManager.activeAccountId {
                            switchAccount(to: account.id)
                        }
                        showAccountSwitcher = false
                    }) {
                        HStack(spacing: 10) {
                            // Avatar
                            AvatarImage(
                                url: account.avatar.flatMap { URL(string: $0) },
                                size: 36
                            )

                            // Account info
                            VStack(alignment: .leading, spacing: 2) {
                                Text(account.displayName ?? account.handle)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                Text("@\(account.handle)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            // Checkmark for active account
                            if account.id == accountManager.activeAccountId {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(theme.accentColor)
                                    .fontWeight(.semibold)
                                    .font(.body)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                }
            }
            .listStyle(.plain)
            .navigationTitle("Switch Account")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showAccountSwitcher = false
                    }
                }
            }
        }
        .frame(minWidth: 300, idealHeight: dynamicAccountSwitcherHeight, maxHeight: 500)
    }

    private var dynamicAccountSwitcherHeight: CGFloat {
        // Navigation bar: ~60px
        // Each account row: ~60px (avatar + padding)
        // Bottom safe area/padding: ~20px
        let navigationHeight: CGFloat = 60
        let rowHeight: CGFloat = 60
        let bottomPadding: CGFloat = 20
        let accountCount = CGFloat(accountManager.accounts.count)

        return navigationHeight + (accountCount * rowHeight) + bottomPadding
    }

    @ViewBuilder
    private var timelineContent: some View {
        if viewModel.state.isLoading && viewModel.state.posts.isEmpty {
            loadingView
        } else if let errorMessage = viewModel.state.errorMessage, viewModel.state.posts.isEmpty {
            errorView(message: errorMessage)
        } else if viewModel.state.posts.isEmpty {
            emptyView
        } else {
            postsListView
        }
    }

    // MARK: - Subviews

    private var loadingView: some View {
        VStack {
            ProgressView()
            Text("Loading timeline...")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
    }

    private func errorView(message: String) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                Text("Unable to load timeline")
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button("Try Again") {
                    Task { await viewModel.refresh() }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    private var emptyView: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "tray")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Your timeline is empty")
                    .font(.headline)
                Text("Start following people to see their posts here")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    private var postsListView: some View {
        scrollableContent
            .onChange(of: viewModel.state.posts.count) { oldCount, newCount in
                // Show content when we have posts
                if newCount > 0 && !showContent {
                    DispatchQueue.main.async {
                        showContent = true
                    }
                }
            }
            .onChange(of: viewModel.state.isLoading) { _, isLoading in
                // Safety net: ensure content is shown when loading completes
                if !isLoading && !viewModel.state.posts.isEmpty && !showContent {
                    DispatchQueue.main.async {
                        showContent = true
                    }
                }
            }
            .onChange(of: viewModel.state.selectedFeed) { oldFeed, newFeed in
                // Reset state when switching feeds
                if oldFeed != nil {
                    showContent = false
                    FeedLogger.changed(from: oldFeed?.displayName, to: newFeed?.displayName ?? "nil")
                }
            }
            .onAppear {
                // Final safety net - show content if we have posts
                if !viewModel.state.posts.isEmpty && !showContent {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if !showContent {
                            FeedLogger.fallback("Showing content via onAppear")
                            showContent = true
                        }
                    }
                }
            }
    }

    private var scrollableContent: some View {
        ZStack(alignment: .top) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.state.posts) { feedPost in
                        PostCell(
                            feedPost: feedPost,
                            viewModel: viewModel,
                            currentTime: currentTime,
                            urlToOpen: $urlToOpen,
                            profileToShow: $profileToShow,
                            hashtagToSearch: $hashtagToSearch,
                            postDetailToShow: $postDetailToShow,
                            embeddedPostDetailToShow: $embeddedPostDetailToShow
                        )
                        .id(feedPost.id)
                        .onAppear {
                            viewModel.state.visiblePostURI = feedPost.post.uri
                            viewModel.markPostAsSeen(feedPost.post.uri)
                            viewModel.prefetchImagesForUpcomingPosts(currentPostId: feedPost.id)
                        }
                        Divider()
                    }

                    if viewModel.state.cursor != nil {
                        ProgressView()
                            .padding()
                            .onAppear {
                                Task { await viewModel.loadMore() }
                            }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollPosition(id: $scrollPosition, anchor: .top)
            .scrollsToTop(true)
            .onChange(of: viewModel.state.savedScrollAnchor) { _, savedAnchor in
                // Restore scroll position to saved anchor once
                if let anchor = savedAnchor,
                   scrollPosition == nil,
                   let anchorPost = viewModel.state.posts.first(where: { $0.post.uri == anchor }) {
                    scrollPosition = anchorPost.id
                    FeedLogger.fallback("Restored scroll to anchor: \(anchor)")
                }
            }
            .onChange(of: scrollPosition) { _, newValue in
                guard let newValue,
                      let post = viewModel.state.posts.first(where: { $0.id == newValue }) else {
                    return
                }
                viewModel.state.visiblePostURI = post.post.uri
            }
            .onChange(of: viewModel.state.shouldAutoInsert) { _, shouldInsert in
                guard shouldInsert else { return }

                let pendingCount = viewModel.state.pendingNewPosts.count
                FeedLogger.insertingPosts(count: pendingCount, locked: true)

                // Reset the trigger
                viewModel.state.shouldAutoInsert = false

                // Disable animations during insertion
                var transaction = Transaction()
                transaction.disablesAnimations = true
                transaction.animation = nil

                // Capture current scroll position before insertion
                let anchorPostId = scrollPosition ?? viewModel.state.posts.first?.id

                withTransaction(transaction) {
                    // Insert pending posts
                    viewModel.insertPendingPosts()

                    // Restore scroll position to keep user at same spot
                    if let postId = anchorPostId {
                        scrollPosition = postId
                        ScrollLogger.restored(postId)
                    }
                }
            }

            // Floating "New posts" banner overlay (posts are auto-inserted above)
            if viewModel.state.unseenPostsCount > 0 {
                VStack {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.body)
                        Text("\(viewModel.state.unseenPostsCount) new \(viewModel.state.unseenPostsCount == 1 ? "post" : "posts")")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(theme.accentColor)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                    .padding(.top, 8)
                    .onTapGesture {
                        // Insert the pending new posts at the top of the timeline
                        viewModel.insertPendingPosts()

                        // Clear the unseen count since user is viewing them
                        viewModel.clearNewPostsTracking()

                        // Scroll to top to see the newly inserted posts
                        if let firstPost = viewModel.state.posts.first {
                            scrollPosition = firstPost.id
                        }
                    }

                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Error banner when background fetch fails
            if viewModel.state.backgroundFetchError != nil {
                VStack {
                    Button(action: {
                        Task {
                            await viewModel.refresh()
                        }
                    }) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.body)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Timeline updates paused")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("Tap to retry")
                                    .font(.caption)
                            }
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(theme.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                    }
                    .padding(.top, 8)

                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .opacity(showContent ? 1 : 0)
        .animation(.easeIn(duration: 0.2), value: showContent)
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - Helper Functions

    @Sendable
    private func loadInitialData() async {
        if viewModel.state.posts.isEmpty {
            await viewModel.loadTimeline()
        }
        await viewModel.startBackgroundFetching()

        // Track timeline view
        TimelineAnalytics.logTimelineViewed()
    }

    private func stopBackgroundFetch() {
        viewModel.stopBackgroundFetching()
    }

    private func switchAccount(to accountId: String) {
        // Show transition overlay with animation
        withAnimation(.easeInOut(duration: 0.3)) {
            isTransitioningAccounts = true
        }

        // Perform account switch after a short delay
        Task {
            // Wait for animation to complete
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

            // Switch account in AccountManager (this triggers the notification)
            accountManager.switchAccount(to: accountId)

            // Wait a bit longer for data to load
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            // Hide transition overlay
            withAnimation(.easeInOut(duration: 0.3)) {
                isTransitioningAccounts = false
            }

            AccountLogger.switchComplete()
        }
    }

    private func handleScenePhaseChange(_ oldPhase: ScenePhase, _ newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            Task {
                await viewModel.startBackgroundFetching()
            }
            LifecycleLogger.appActive()
        case .background:
            viewModel.persistScrollState()
            if let uri = viewModel.state.visiblePostURI {
                ScrollLogger.saved(uri, context: "app backgrounded")
            }
            viewModel.stopBackgroundFetching()
            LifecycleLogger.appBackgrounded()
        case .inactive:
            viewModel.persistScrollState()
            break
        @unknown default:
            break
        }
    }

}
struct PostCell: View {
    let feedPost: FeedViewPost
    let viewModel: TimelineViewModel
    let currentTime: Date
    @Binding var urlToOpen: URL?
    @Binding var profileToShow: String?
    @Binding var hashtagToSearch: String?
    @Binding var postDetailToShow: String?
    @Binding var embeddedPostDetailToShow: String?

    @State private var showingReplyComposer = false
    @State private var isContentRevealed = false
    @EnvironmentObject var theme: AppTheme
    @StateObject private var moderationPreferences = ModerationPreferences.shared

    var post: Post {
        feedPost.post
    }

    var moderationAction: ModerationAction {
        post.moderationAction(settings: moderationPreferences.settings)
    }

    var postURL: URL {
        // Extract rkey from URI (format: at://did/app.bsky.feed.post/rkey)
        let rkey = post.uri.split(separator: "/").last ?? ""
        return URL(string: "https://bsky.app/profile/\(post.author.safeHandle)/post/\(rkey)") ?? URL(string: "https://bsky.app")!
    }

    private func relativeTime(from date: Date) -> String {
        let interval = currentTime.timeIntervalSince(date)

        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)

        if days > 0 {
            return "\(days)d"
        } else if hours > 0 {
            return "\(hours)h"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "now"
        }
    }

    var body: some View {
        Button(action: {
            postDetailToShow = post.uri
        }) {
            postContent
        }
        .buttonStyle(PostCellButtonStyle())
        #if os(iOS)
        .fullScreenCover(isPresented: $showingReplyComposer) {
            PostComposerView(
                replyTo: ReplyRef(
                    root: PostRef(uri: post.uri, cid: post.cid),
                    parent: PostRef(uri: post.uri, cid: post.cid)
                )
            ) { posted in
                if posted {
                    Task {
                        await viewModel.refresh()
                    }
                }
            }
        }
        #else
        .sheet(isPresented: $showingReplyComposer) {
            PostComposerView(
                replyTo: ReplyRef(
                    root: PostRef(uri: post.uri, cid: post.cid),
                    parent: PostRef(uri: post.uri, cid: post.cid)
                )
            ) { posted in
                if posted {
                    Task {
                        await viewModel.refresh()
                    }
                }
            }
        }
        #endif
    }

    private var postContent: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 12) {
            // Reply context (show parent posts in thread)
            if let reply = feedPost.reply {
                ReplyContextView(
                    replyContext: reply,
                    currentTime: currentTime,
                    profileToShow: $profileToShow,
                    postDetailToShow: $postDetailToShow
                )
                .equatable()
                .padding(.bottom, 8)
            }

            // Repost indicator
            if let reason = feedPost.reason, let by = reason.by {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.2.squarepath")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(by.displayName ?? by.handle ?? "ERROR") reposted")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 4)
            }

            // Author info
            HStack(alignment: .top, spacing: 12) {
                Button {
                    profileToShow = post.author.safeHandle
                } label: {
                    HStack(spacing: 12) {
                        // Avatar with retry logic
                        AvatarImage(
                            url: post.author.avatar.flatMap { URL(string: $0) },
                            size: 48
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text((post.author.displayName?.isEmpty == false) ? post.author.displayName! : post.author.shortHandle)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)

                            Text("@\(post.author.safeHandle)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Text(relativeTime(from: post.createdAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Post content
            #if os(iOS)
            AttributedTextView(
                text: post.record.text,
                facets: post.record.facets,
                font: .preferredFont(forTextStyle: .body),
                textColor: .label,
                accentColor: theme.accentColor
            ) { item in
                switch item {
                case .url(let url):
                    urlToOpen = url
                case .mention(let did):
                    profileToShow = did
                case .hashtag(let tag):
                    hashtagToSearch = tag
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            #else
            AttributedTextView(
                text: post.record.text,
                facets: post.record.facets,
                font: .systemFont(ofSize: NSFont.systemFontSize),
                textColor: .labelColor,
                accentColor: theme.accentColor
            ) { item in
                switch item {
                case .url(let url):
                    urlToOpen = url
                case .mention(let did):
                    profileToShow = did
                case .hashtag(let tag):
                    hashtagToSearch = tag
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            #endif

            // Images if present (either direct or in media with quote post)
            if let images = post.embed?.images, !images.isEmpty {
                ImageGrid(images: images)
            } else if let images = post.embed?.media?.images, !images.isEmpty {
                // Images from recordWithMedia (quote post with images)
                ImageGrid(images: images)
            }

            // Video if present (either direct video or video in media)
            if let video = post.embed?.video {
                VideoPlayerView(video: video)
                    .frame(maxHeight: 400)
            } else if let video = post.embed?.media?.video {
                // Video from recordWithMedia (quote post with video)
                VideoPlayerView(video: video)
                    .frame(maxHeight: 400)
            }

            // External link preview if present
            if let external = post.embed?.external {
                ExternalLinkPreview(external: external, urlToOpen: $urlToOpen)
            }

            // Embedded/quoted post if present
            if let embeddedRecord = post.embed?.record {
                // Don't pass media - it belongs to the parent post, not the embedded post
                EmbeddedPostView(record: embeddedRecord, media: nil, currentTime: currentTime, postDetailURI: $embeddedPostDetailToShow)
                    .equatable()
            }

            // Action buttons
            HStack(spacing: 40) {
                Button(action: {
                    showingReplyComposer = true
                    Analytics.logEvent("post_interaction", parameters: [
                        "action": "reply",
                        "post_id": post.uri
                    ])
                    AnalyticsLogger.logEvent("post_interaction", parameters: ["action": "reply"])
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left").font(.body)
                        if let count = post.replyCount, count > 0 {
                            Text("\(count)").font(.caption)
                        }
                    }.foregroundStyle(.secondary)
                }

                Button(action: {
                    Task {
                        await viewModel.toggleRepost(for: post)
                        Analytics.logEvent("post_interaction", parameters: [
                            "action": "repost",
                            "post_id": post.uri
                        ])
                        AnalyticsLogger.logEvent("post_interaction", parameters: ["action": "repost"])
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: post.viewer?.repost != nil ? "arrow.2.squarepath.fill" : "arrow.2.squarepath")
                            .font(.body)
                            .symbolEffect(.bounce, value: post.viewer?.repost)
                        if let count = post.repostCount, count > 0 {
                            Text("\(count)").font(.caption).contentTransition(.numericText())
                        }
                    }.foregroundStyle(post.viewer?.repost != nil ? .green : .secondary)
                }

                Button(action: {
                    Task {
                        await viewModel.toggleLike(for: post)
                        Analytics.logEvent("post_interaction", parameters: [
                            "action": "like",
                            "post_id": post.uri
                        ])
                        AnalyticsLogger.logEvent("post_interaction", parameters: ["action": "like"])
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: post.viewer?.like != nil ? "heart.fill" : "heart")
                            .font(.body)
                            .symbolEffect(.bounce, value: post.viewer?.like)
                        if let count = post.likeCount, count > 0 {
                            Text("\(count)").font(.caption).contentTransition(.numericText())
                        }
                    }.foregroundStyle(post.viewer?.like != nil ? .pink : .secondary)
                }

                Spacer()

                ShareLink(item: postURL) {
                    Image(systemName: "square.and.arrow.up").font(.body).foregroundStyle(.secondary)
                }
            }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .blur(radius: (moderationAction == .warn && !isContentRevealed) ? 20 : 0)

            // Blur overlay for warned content
            if moderationAction == .warn && !isContentRevealed {
                Button(action: {
                    isContentRevealed = true
                }) {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.orange)

                        VStack(spacing: 8) {
                            Text("Content Warning")
                                .font(.headline)
                                .fontWeight(.bold)

                            Text("This post may contain sensitive content")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)

                            Text("Tap to view")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(theme.accentColor)
                                .padding(.top, 4)
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    #if os(iOS)
                    .background(Color(.systemBackground).opacity(0.95))
                    #else
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.95))
                    #endif
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// Helper to make URL Identifiable for sheet presentation
struct URLWrapper: Identifiable {
    var id: String { url.absoluteString }
    let url: URL
}

// Helper to make actor string Identifiable for navigation
struct ProfileWrapper: Identifiable, Hashable {
    var id: String { actor }
    let actor: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(actor)
    }

    static func == (lhs: ProfileWrapper, rhs: ProfileWrapper) -> Bool {
        lhs.actor == rhs.actor
    }
}

// Helper to make hashtag string Identifiable for navigation
struct HashtagWrapper: Identifiable, Hashable {
    var id: String { tag }
    let tag: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(tag)
    }

    static func == (lhs: HashtagWrapper, rhs: HashtagWrapper) -> Bool {
        lhs.tag == rhs.tag
    }
}

struct ImageGrid: View {
    let images: [ImageView]
    @State private var selectedImageIndex: Int?

    // Fixed dimensions to prevent layout jumping
    private let singleImageSize: CGFloat = 300  // Big square for single image
    private let gridSpacing: CGFloat = 4

    var body: some View {
        Group {
            if images.count == 1 {
                // Single image: big square (300x300)
                singleImageView(image: images[0], index: 0)
            } else if images.count == 2 {
                // Two images: side by side (150x300 each)
                HStack(spacing: gridSpacing) {
                    gridImageView(image: images[0], index: 0, height: singleImageSize)
                    gridImageView(image: images[1], index: 1, height: singleImageSize)
                }
                .frame(height: singleImageSize)
            } else if images.count == 3 {
                // Three images: one on top (full width, 148pt), two below (half width, 148pt each)
                // Total height: 300pt (148 + 4 spacing + 148)
                VStack(spacing: gridSpacing) {
                    gridImageView(image: images[0], index: 0, height: 148)
                    HStack(spacing: gridSpacing) {
                        gridImageView(image: images[1], index: 1, height: 148)
                        gridImageView(image: images[2], index: 2, height: 148)
                    }
                }
                .frame(height: singleImageSize)
            } else {
                // Four images: 2x2 grid (148x148 each)
                // Total height: 300pt (148 + 4 spacing + 148)
                VStack(spacing: gridSpacing) {
                    HStack(spacing: gridSpacing) {
                        gridImageView(image: images[0], index: 0, height: 148)
                        gridImageView(image: images[1], index: 1, height: 148)
                    }
                    HStack(spacing: gridSpacing) {
                        gridImageView(image: images[2], index: 2, height: 148)
                        gridImageView(image: images[3], index: 3, height: 148)
                    }
                }
                .frame(height: singleImageSize)
            }
        }
        #if os(iOS)
        .fullScreenCover(item: Binding(
            get: { selectedImageIndex.map { ImageIndexWrapper(index: $0) } },
            set: { selectedImageIndex = $0?.index }
        )) { wrapper in
            FullScreenImageView(images: images, initialIndex: wrapper.index)
        }
        #else
        .sheet(item: Binding(
            get: { selectedImageIndex.map { ImageIndexWrapper(index: $0) } },
            set: { selectedImageIndex = $0?.index }
        )) { wrapper in
            FullScreenImageView(images: images, initialIndex: wrapper.index)
        }
        #endif
    }

    // Single image view: big square with aspect fill
    private func singleImageView(image: ImageView, index: Int) -> some View {
        Button {
            selectedImageIndex = index
        } label: {
            RetryableAsyncImage(
                url: URL(string: image.thumb),
                maxRetries: 3,
                retryDelay: 1.0,
                content: { img in
                    img
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: singleImageSize, height: singleImageSize)
                },
                placeholder: {
                    ZStack {
                        Color.gray.opacity(0.1)
                        ProgressView()
                    }
                    .frame(width: singleImageSize, height: singleImageSize)
                }
            )
            .frame(width: singleImageSize, height: singleImageSize)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .bottomLeading) {
                if !image.alt.isEmpty {
                    Text("ALT")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(8)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            ImageContextMenu(imageURL: image.fullsize)
        }
    }

    // Grid image view: flexible width, fixed height with aspect fill
    private func gridImageView(image: ImageView, index: Int, height: CGFloat) -> some View {
        Button {
            selectedImageIndex = index
        } label: {
            GeometryReader { geometry in
                RetryableAsyncImage(
                    url: URL(string: image.thumb),
                    maxRetries: 3,
                    retryDelay: 1.0,
                    content: { img in
                        img
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: height)
                    },
                    placeholder: {
                        ZStack {
                            Color.gray.opacity(0.1)
                            ProgressView()
                        }
                        .frame(width: geometry.size.width, height: height)
                    }
                )
                .frame(width: geometry.size.width, height: height)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .bottomLeading) {
                    if !image.alt.isEmpty {
                        Text("ALT")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.black.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(4)
                    }
                }
            }
            .frame(height: height)
        }
        .buttonStyle(.plain)
        .contextMenu {
            ImageContextMenu(imageURL: image.fullsize)
        }
    }
}

// Helper wrapper to make Int identifiable for fullScreenCover
struct ImageIndexWrapper: Identifiable {
    var id: Int { index }
    let index: Int
}

// MARK: - Image Context Menu for Download/Share
struct ImageContextMenu: View {
    let imageURL: String
    @State private var showShareSheet = false
    @State private var imageToShare: UIImage?
    @State private var isDownloading = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    var body: some View {
        Button {
            Task {
                await downloadAndShare()
            }
        } label: {
            SwiftUI.Label("Share Image", systemImage: "square.and.arrow.up")
        }
        .disabled(isDownloading)

        Button {
            Task {
                await saveImage()
            }
        } label: {
            SwiftUI.Label("Save to Photos", systemImage: "square.and.arrow.down")
        }
        .disabled(isDownloading)
        .sheet(isPresented: $showShareSheet) {
            if let image = imageToShare {
                ShareSheet(items: [image])
            }
        }
        .overlay {
            if isDownloading {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)

                        Text("Downloading image...")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }
                    .padding(24)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .alert("Saved", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Image saved to Photos")
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private func downloadAndShare() async {
        guard let url = URL(string: imageURL) else {
            showError("Invalid image URL")
            return
        }

        await MainActor.run { isDownloading = true }
        defer { Task { @MainActor in isDownloading = false } }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else {
                showError("Failed to load image")
                return
            }

            await MainActor.run {
                imageToShare = image
                showShareSheet = true
            }
        } catch {
            showError("Failed to download image: \(error.localizedDescription)")
        }
    }

    private func saveImage() async {
        guard let url = URL(string: imageURL) else {
            showError("Invalid image URL")
            return
        }

        await MainActor.run { isDownloading = true }
        defer { Task { @MainActor in isDownloading = false } }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else {
                showError("Failed to load image")
                return
            }

            await MainActor.run {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                showSuccessAlert = true
            }
        } catch {
            showError("Failed to download image: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func showError(_ message: String) {
        errorMessage = message
        showErrorAlert = true
        AppLogger.error("Image download/save failed", error: nil, subsystem: "UI")
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No update needed
    }
}

// MARK: - Custom Button Style
struct PostCellButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
    }
}

// MARK: - Embedded Post View
struct EmbeddedPostView: View, Equatable {
    let record: EmbeddedPostRecord
    let media: MediaEmbed?  // Media from recordWithMedia embed
    let currentTime: Date
    @Binding var postDetailURI: String?

    // Equatable conformance - compare by record URI to avoid unnecessary redraws
    static func == (lhs: EmbeddedPostView, rhs: EmbeddedPostView) -> Bool {
        lhs.record.uri == rhs.record.uri
    }

    private func relativeTime(from dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let date = formatter.date(from: dateString) ?? {
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: dateString)
        }() else {
            return ""
        }

        let interval = currentTime.timeIntervalSince(date)

        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)

        if days > 0 {
            return "\(days)d"
        } else if hours > 0 {
            return "\(hours)h"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "now"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Debug logging
            let _ = AppLogger.debug("EmbeddedPostView - author: \(record.author != nil), value: \(record.value != nil), uri: \(record.uri ?? "nil")", subsystem: "UI")

            if let author = record.author, let value = record.value {
                // Author info
                HStack(alignment: .top, spacing: 8) {
                    AvatarImage(
                        url: author.avatar.flatMap { URL(string: $0) },
                        size: 24,
                        borderWidth: 2
                    )

                    VStack(alignment: .leading, spacing: 0) {
                        Text((author.displayName?.isEmpty == false) ? author.displayName! : author.shortHandle)
                            .font(.caption)
                            .fontWeight(.semibold)

                        Text("@\(author.safeHandle)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if let indexedAt = record.indexedAt {
                        Text(relativeTime(from: indexedAt))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // Post text
                Text(value.text)
                    .font(.caption)
                    .lineLimit(6)

                // Check for media from recordWithMedia first (media attached to the QUOTED post)
                if let mediaEmbed = media {
                    if let images = mediaEmbed.images, !images.isEmpty {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4)], spacing: 4) {
                            ForEach(images.prefix(4)) { image in
                                GeometryReader { geometry in
                                    RetryableAsyncImage(
                                        url: URL(string: image.thumb),
                                        maxRetries: 3,
                                        retryDelay: 1.0,
                                        content: { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: geometry.size.width, height: 80)
                                        },
                                        placeholder: {
                                            ZStack {
                                                Color.gray.opacity(0.1)
                                                ProgressView()
                                            }
                                            .frame(width: geometry.size.width, height: 80)
                                        }
                                    )
                                    .frame(width: geometry.size.width, height: 80)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                .frame(height: 80)
                            }
                        }
                    }

                    if let video = mediaEmbed.video {
                        VideoPlayerView(video: video)
                            .frame(height: 150)
                    }
                }

                // Embedded images if present (from record.embeds)
                if let embeds = record.embeds, !embeds.isEmpty {
                    ForEach(Array(embeds.enumerated()), id: \.offset) { index, embed in
                        if let images = embed.images, !images.isEmpty {
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4)], spacing: 4) {
                                ForEach(images.prefix(4)) { image in
                                    GeometryReader { geometry in
                                        RetryableAsyncImage(
                                            url: URL(string: image.thumb),
                                            maxRetries: 3,
                                            retryDelay: 1.0,
                                            content: { image in
                                                image
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: geometry.size.width, height: 80)
                                            },
                                            placeholder: {
                                                ZStack {
                                                    Color.gray.opacity(0.1)
                                                    ProgressView()
                                                }
                                                .frame(width: geometry.size.width, height: 80)
                                            }
                                        )
                                        .frame(width: geometry.size.width, height: 80)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                    .frame(height: 80)
                                }
                            }
                        }

                        // Embedded video if present
                        if let video = embed.video {
                            VideoPlayerView(video: video)
                                .frame(height: 150)
                        }
                    }
                }

                // Stats
                HStack(spacing: 12) {
                    if let count = record.replyCount, count > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "bubble.left")
                            Text("\(count)")
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }

                    if let count = record.repostCount, count > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.2.squarepath")
                            Text("\(count)")
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }

                    if let count = record.likeCount, count > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "heart")
                            Text("\(count)")
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }
            } else {
                // Fallback when author or value is missing
                Text("Quoted post unavailable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
        .onTapGesture {
            if let uri = record.uri {
                postDetailURI = uri
            }
        }
    }
}

// MARK: - Helper Wrappers
struct URIWrapper: Identifiable, Hashable {
    var id: String { uri }
    let uri: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(uri)
    }

    static func == (lhs: URIWrapper, rhs: URIWrapper) -> Bool {
        lhs.uri == rhs.uri
    }
}

// MARK: - External Link Preview
struct ExternalLinkPreview: View {
    let external: ExternalView
    @Binding var urlToOpen: URL?

    var body: some View {
        Button {
            if let url = URL(string: external.uri) {
                urlToOpen = url
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Thumbnail image if present
                if let thumbURL = external.thumb {
                    RetryableAsyncImage(
                        url: URL(string: thumbURL),
                        maxRetries: 3,
                        retryDelay: 1.0,
                        content: { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: .infinity)
                                .frame(height: 200)
                        },
                        placeholder: {
                            ZStack {
                                Color.gray.opacity(0.1)
                                Image(systemName: "link")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                        }
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipped()
                }

                // Title and description
                VStack(alignment: .leading, spacing: 4) {
                    Text(external.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    if !external.description.isEmpty {
                        Text(external.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    // Domain
                    if let url = URL(string: external.uri), let host = url.host {
                        Text(host)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
            }
            .frame(maxWidth: .infinity)
            #if os(iOS)
            .background(Color(.systemBackground))
            #else
            .background(Color(nsColor: .controlBackgroundColor))
            #endif
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Reply Context View
struct ReplyContextView: View, Equatable {
    let replyContext: ReplyContext
    let currentTime: Date
    @Binding var profileToShow: String?
    @Binding var postDetailToShow: String?
    @EnvironmentObject var theme: AppTheme

    // Equatable conformance - compare by post URIs to avoid unnecessary redraws
    static func == (lhs: ReplyContextView, rhs: ReplyContextView) -> Bool {
        lhs.replyContext.parent?.uri == rhs.replyContext.parent?.uri &&
        lhs.replyContext.root?.uri == rhs.replyContext.root?.uri
    }

    private func relativeTime(from date: Date) -> String {
        let interval = currentTime.timeIntervalSince(date)

        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)

        if days > 0 {
            return "\(days)d"
        } else if hours > 0 {
            return "\(hours)h"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "now"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Show parent post (the one directly replied to)
            if let parent = replyContext.parent {
                ReplyThreadItem(
                    post: parent,
                    currentTime: currentTime,
                    isLast: false,
                    profileToShow: $profileToShow,
                    postDetailToShow: $postDetailToShow
                )
            }
        }
    }
}

// MARK: - Reply Thread Item
struct ReplyThreadItem: View {
    let post: Post
    let currentTime: Date
    let isLast: Bool
    @Binding var profileToShow: String?
    @Binding var postDetailToShow: String?
    @EnvironmentObject var theme: AppTheme

    private func relativeTime(from date: Date) -> String {
        let interval = currentTime.timeIntervalSince(date)

        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)

        if days > 0 {
            return "\(days)d"
        } else if hours > 0 {
            return "\(hours)h"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "now"
        }
    }

    var body: some View {
        Button(action: {
            postDetailToShow = post.uri
        }) {
            HStack(alignment: .top, spacing: 12) {
                // Avatar with connecting line (non-interactive in thread context)
                VStack(spacing: 0) {
                    AvatarImage(
                        url: post.author.avatar.flatMap { URL(string: $0) },
                        size: 32,
                        borderWidth: 2
                    )

                    if !isLast {
                        Rectangle()
                            .fill(theme.accentColor.opacity(0.3))
                            .frame(width: 2)
                            .padding(.top, 4)
                    }
                }
                .frame(width: 32)

                // Post content
                VStack(alignment: .leading, spacing: 6) {
                    // Author and time
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text((post.author.displayName?.isEmpty == false) ? post.author.displayName! : post.author.shortHandle)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)

                            Text("@\(post.author.safeHandle)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(relativeTime(from: post.createdAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Post text (truncated)
                    if !post.record.text.isEmpty {
                        Text(post.record.text)
                            .font(.subheadline)
                            .lineLimit(6)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, isLast ? 0 : 8)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.accentColor.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    TimelineView()
}
