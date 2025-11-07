//
//  ProfileView.swift
//  Skyscraper
//
//  User profile view with segmented content switching
//

import SwiftUI
import Combine

enum ProfileSegment: String, CaseIterable {
    case posts = "Posts"
    case replies = "Replies"
    case likes = "Likes"
    case lists = "Lists"
    case starterPacks = "Starters"
}

struct ProfileView: View {
    let actor: String
    @State private var profile: Profile?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingLogoutConfirmation = false
    @State private var selectedSegment: ProfileSegment = .posts
    @State private var posts: [FeedViewPost] = []
    @State private var pinnedPost: FeedViewPost?  // Pinned post if exists
    @State private var userLists: [ListView] = []
    @State private var starterPacks: [StarterPack] = []
    @State private var isLoadingContent = false
    @State private var contentCursor: String?
    @State private var postDetailToShow: String?
    @State private var embeddedPostDetailToShow: String?
    @State private var urlToOpen: URL?
    @State private var profileToShow: String?
    @State private var hashtagToSearch: String?
    @State private var currentTime = Date()
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var theme: AppTheme

    private let client = ATProtoClient.shared
    private let timeUpdateTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    private enum Layout {
        static let feedHorizontalPadding: CGFloat = 0
        static let contentHorizontalPadding: CGFloat = 16
        static let sectionSpacing: CGFloat = 24
        static let bannerHeight: CGFloat = 200
        static let avatarSize: CGFloat = 96
        static let avatarOverlap: CGFloat = 48
    }

    var isCurrentUser: Bool {
        profile?.did == client.session?.did
    }

    // Only show certain segments based on whether viewing current user
    private var availableSegments: [ProfileSegment] {
        if isCurrentUser {
            return ProfileSegment.allCases
        } else {
            // Hide likes tab for other users (API restriction)
            return ProfileSegment.allCases.filter { $0 != .likes }
        }
    }

    private var emptyStateMessage: String {
        switch selectedSegment {
        case .posts:
            return "No posts yet"
        case .replies:
            return "No replies yet"
        case .likes:
            return "No likes yet"
        default:
            return "No content yet"
        }
    }

    private var postDetailBinding: Binding<URIWrapper?> {
        Binding(
            get: { postDetailToShow.map { URIWrapper(uri: $0) } },
            set: { postDetailToShow = $0?.uri }
        )
    }

    private var embeddedPostDetailBinding: Binding<URIWrapper?> {
        Binding(
            get: { embeddedPostDetailToShow.map { URIWrapper(uri: $0) } },
            set: { embeddedPostDetailToShow = $0?.uri }
        )
    }

    private var profileBinding: Binding<ProfileWrapper?> {
        Binding(
            get: { profileToShow.map { ProfileWrapper(actor: $0) } },
            set: { profileToShow = $0?.actor }
        )
    }

    private var hashtagBinding: Binding<HashtagWrapper?> {
        Binding(
            get: { hashtagToSearch.map { HashtagWrapper(tag: $0) } },
            set: { hashtagToSearch = $0?.tag }
        )
    }

    private var urlSheetBinding: Binding<URLWrapper?> {
        Binding(
            get: { urlToOpen.map { URLWrapper(url: $0) } },
            set: { urlToOpen = $0?.url }
        )
    }

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let profile {
                profileContent(for: profile)
            } else if let errorMessage {
                errorState(message: errorMessage)
            } else {
                EmptyView()
            }
        }
        .navigationTitle("Profile")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationDestination(item: postDetailBinding) { wrapper in
            PostDetailView(postURI: wrapper.uri)
        }
        .navigationDestination(item: embeddedPostDetailBinding) { wrapper in
            PostDetailView(postURI: wrapper.uri)
        }
        .navigationDestination(item: profileBinding) { wrapper in
            ProfileView(actor: wrapper.actor)
        }
        .navigationDestination(item: hashtagBinding) { wrapper in
            HashtagSearchView(hashtag: wrapper.tag)
        }
        .sheet(item: urlSheetBinding) { wrapper in
            SafariView(url: wrapper.url)
        }
        .toolbar {
            if isCurrentUser {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingLogoutConfirmation = true
                    } label: {
                        Text("Log Out")
                            .foregroundStyle(.red)
                    }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button {
                        showingLogoutConfirmation = true
                    } label: {
                        Text("Log Out")
                            .foregroundStyle(.red)
                    }
                }
                #endif
            }
        }
        .alert("Log Out", isPresented: $showingLogoutConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Log Out", role: .destructive) {
                authViewModel.logout()
            }
        } message: {
            Text("Are you sure you want to log out of this account?")
        }
        .task {
            await loadProfile()
        }
        .onChange(of: selectedSegment) { _, _ in
            Task {
                await loadContent()
            }
        }
        .onReceive(timeUpdateTimer) { _ in
            currentTime = Date()
        }
    }

    // MARK: - Top-Level States

    private var loadingView: some View {
        ProgressView()
            .padding()
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    @ViewBuilder
    private func profileContent(for profile: Profile) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                headerSection(for: profile)

                segmentPicker

                if isLoadingContent {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                } else {
                    contentView
                }
            }
            .padding(.horizontal, Layout.feedHorizontalPadding)
            .padding(.vertical, 24)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func headerSection(for profile: Profile) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            ZStack(alignment: .bottomLeading) {
                bannerView(for: profile)

                HStack(alignment: .bottom) {
                    AvatarImage(
                        url: profile.avatar.flatMap { URL(string: $0) },
                        size: Layout.avatarSize
                    )
                    .overlay(
                        Circle()
                            .stroke(theme.accentColor, lineWidth: 4)
                    )
                    .background(
                        Circle()
                            #if os(iOS)
                            .fill(Color(uiColor: .systemBackground))
                            #else
                            .fill(Color(nsColor: .windowBackgroundColor))
                            #endif
                    )
                    .clipShape(Circle())
                    .shadow(radius: 4)
                    .offset(y: Layout.avatarOverlap)

                    Spacer()

                    if !isCurrentUser {
                        followButton(for: profile)
                            .offset(y: Layout.avatarOverlap)
                    }
                }
                .padding(.horizontal, Layout.contentHorizontalPadding)
            }
            .padding(.bottom, Layout.avatarOverlap)

            VStack(alignment: .leading, spacing: 12) {
                if let displayName = profile.displayName, !displayName.isEmpty {
                    Text(displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                }

                Text("@\(profile.handle)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let description = profile.description, !description.isEmpty {
                    Text(description)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 24) {
                    StatView(count: profile.postsCount ?? 0, label: "Posts")
                    StatView(count: profile.followersCount ?? 0, label: "Followers")
                    StatView(count: profile.followsCount ?? 0, label: "Following")
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, Layout.contentHorizontalPadding)
        }
    }

    @ViewBuilder
    private func bannerView(for profile: Profile) -> some View {
        if let bannerURL = profile.banner, let url = URL(string: bannerURL) {
            RetryableAsyncImage(
                url: url,
                maxRetries: 3,
                retryDelay: 1.0,
                content: { image in
                    image
                        .resizable()
                        .aspectRatio(3, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .clipped()
                },
                placeholder: {
                    Rectangle()
                        .fill(defaultBannerGradient)
                        .frame(height: Layout.bannerHeight)
                }
            )
        } else {
            Rectangle()
                .fill(defaultBannerGradient)
                .frame(height: Layout.bannerHeight)
        }
    }

    private var defaultBannerGradient: LinearGradient {
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @ViewBuilder
    private func followButton(for profile: Profile) -> some View {
        Button {
            Task {
                await toggleFollow()
            }
        } label: {
            let isFollowing = profile.viewer?.following != nil
            Text(isFollowing ? "Following" : "Follow")
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(minWidth: 100)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(isFollowing ? Color.secondary.opacity(0.2) : Color.accentColor)
                .foregroundStyle(isFollowing ? Color.primary : Color.white)
                .clipShape(Capsule())
        }
    }

    private var segmentPicker: some View {
        Picker("Content Type", selection: $selectedSegment) {
            ForEach(availableSegments, id: \.self) { segment in
                Text(segment.rawValue).tag(segment)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, Layout.contentHorizontalPadding)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        switch selectedSegment {
        case .posts, .replies, .likes:
            postsContent
        case .lists:
            listsContent
        case .starterPacks:
            starterPacksContent
        }
    }

    @ViewBuilder
    private var postsContent: some View {
        if posts.isEmpty && pinnedPost == nil {
            emptyState(
                systemImage: "doc.text",
                message: emptyStateMessage
            )
        } else {
            LazyVStack(spacing: 0) {
                // Show pinned post at the top if exists
                if let pinnedPost {
                    ProfileFeedPostCell(
                        feedPost: pinnedPost,
                        currentTime: currentTime,
                        isPinned: true,
                        urlToOpen: $urlToOpen,
                        profileToShow: $profileToShow,
                        hashtagToSearch: $hashtagToSearch,
                        postDetailToShow: $postDetailToShow,
                        embeddedPostDetailToShow: $embeddedPostDetailToShow
                    )
                    Divider()
                }

                // Regular posts
                ForEach(posts) { feedPost in
                    ProfileFeedPostCell(
                        feedPost: feedPost,
                        currentTime: currentTime,
                        isPinned: false,
                        urlToOpen: $urlToOpen,
                        profileToShow: $profileToShow,
                        hashtagToSearch: $hashtagToSearch,
                        postDetailToShow: $postDetailToShow,
                        embeddedPostDetailToShow: $embeddedPostDetailToShow
                    )

                    Divider()
                }
            }
        }
    }

    @ViewBuilder
    private var listsContent: some View {
        if userLists.isEmpty {
            emptyState(
                systemImage: "list.bullet",
                message: "No lists created"
            )
        } else {
            LazyVStack(spacing: 0) {
                ForEach(userLists) { list in
                    SimpleListRow(list: list)
                        .padding(.horizontal, 16)

                    Divider()
                        .padding(.horizontal, 16)
                }
            }
        }
    }

    @ViewBuilder
    private var starterPacksContent: some View {
        if starterPacks.isEmpty {
            emptyState(
                systemImage: "star",
                message: "No starter packs created"
            )
        } else {
            LazyVStack(spacing: 0) {
                ForEach(starterPacks) { pack in
                    NavigationLink(destination: StarterPackDetailView(starterPack: pack)) {
                        SimpleStarterPackRow(pack: pack)
                            .padding(.horizontal, 16)
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .padding(.horizontal, 16)
                }
            }
        }
    }

    private func emptyState(systemImage: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(message)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 60)
        .padding(.bottom, 200)
    }

    // MARK: - Data Loading

    private func loadProfile() async {
        isLoading = true
        errorMessage = nil

        do {
            let profiles = try await client.getProfiles(actors: [actor])
            let fetchedProfile: Profile
            if let first = profiles.first {
                fetchedProfile = first
            } else {
                fetchedProfile = try await client.getProfile(actor: actor)
            }

            // Debug: Check if pinned post exists
            if let pinnedRef = fetchedProfile.pinnedPost {
                print("📌 Profile has pinned post: \(pinnedRef.uri)")
            } else {
                print("📌 No pinned post found for profile: \(actor)")
            }

            // Prefetch profile images before showing the profile
            await prefetchProfileImages(for: fetchedProfile)

            // Set profile after images are prefetched
            profile = fetchedProfile

            // Reset to posts tab if viewing another user and likes tab is selected
            // (likes can only be viewed for the logged-in user per API restriction)
            if !isCurrentUser && selectedSegment == .likes {
                selectedSegment = .posts
            }

            await loadContent()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func prefetchProfileImages(for profile: Profile) async {
        var urlsToPrefetch: [URL] = []

        // Collect banner URL
        if let bannerURL = profile.banner, let url = URL(string: bannerURL) {
            urlsToPrefetch.append(url)
        }

        // Collect avatar URL
        if let avatarURL = profile.avatar, let url = URL(string: avatarURL) {
            urlsToPrefetch.append(url)
        }

        // Prefetch all images concurrently
        await withTaskGroup(of: Void.self) { group in
            for url in urlsToPrefetch {
                group.addTask {
                    await self.prefetchImage(url: url)
                }
            }
        }
    }

    private func prefetchImage(url: URL) async {
        // Check if already in cache
        let request = URLRequest(url: url)
        if URLCache.shared.cachedResponse(for: request) != nil {
            return // Already cached
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            // Cache the response
            let cachedResponse = CachedURLResponse(response: response, data: data)
            URLCache.shared.storeCachedResponse(cachedResponse, for: request)
        } catch {
            // Silently fail - images will show placeholder if they fail to load
            print("⚠️ Failed to prefetch profile image: \(url.lastPathComponent)")
        }
    }

    private func loadContent() async {
        isLoadingContent = true
        posts = []
        pinnedPost = nil  // Reset pinned post
        userLists = []
        starterPacks = []
        contentCursor = nil
        errorMessage = nil

        do {
            switch selectedSegment {
            case .posts:
                let response = try await client.getAuthorFeed(actor: actor, filter: "posts_no_replies")
                posts = response.feed
                contentCursor = response.cursor

                // Fetch pinned post if it exists
                if let pinnedPostRef = profile?.pinnedPost {
                    await fetchPinnedPost(uri: pinnedPostRef.uri)
                }
            case .replies:
                let response = try await client.getAuthorFeed(actor: actor, filter: "posts_with_replies")
                posts = response.feed.filter { $0.reply != nil }
                contentCursor = response.cursor

                // Fetch pinned post if it exists
                if let pinnedPostRef = profile?.pinnedPost {
                    await fetchPinnedPost(uri: pinnedPostRef.uri)
                }
            case .likes:
                let response = try await client.getActorLikes(actor: actor)
                posts = response.feed
                contentCursor = response.cursor
            case .lists:
                let response = try await client.getActorLists(actor: actor)
                userLists = response.lists
                contentCursor = response.cursor
            case .starterPacks:
                let response = try await client.getActorStarterPacks(actor: actor)
                starterPacks = response.starterPacks
                contentCursor = response.cursor
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingContent = false
    }

    private func fetchPinnedPost(uri: String) async {
        do {
            let response = try await client.getPosts(uris: [uri])
            if let post = response.posts.first {
                // Don't duplicate if the pinned post is already in the feed
                if !posts.contains(where: { $0.post.uri == post.post.uri }) {
                    pinnedPost = post
                    print("📌 Fetched pinned post: \(post.post.uri)")
                } else {
                    print("📌 Pinned post already in feed, not duplicating")
                }
            }
        } catch {
            print("⚠️ Failed to fetch pinned post: \(error.localizedDescription)")
        }
    }

    private func toggleFollow() async {
        guard let currentProfile = profile else { return }

        // Store original state for rollback
        let originalProfile = currentProfile
        let isFollowing = currentProfile.viewer?.following != nil

        // Optimistically update UI immediately
        var updatedProfile = currentProfile
        if isFollowing {
            // Unfollow: remove the following URI
            updatedProfile.viewer?.following = nil
            updatedProfile.followersCount = max(0, (currentProfile.followersCount ?? 0) - 1)
        } else {
            // Follow: set a temporary URI (will be replaced with real one from server)
            if updatedProfile.viewer == nil {
                updatedProfile.viewer = ProfileViewer(muted: nil as Bool?, blockedBy: nil as Bool?, following: "pending", followedBy: nil as String?)
            } else {
                updatedProfile.viewer?.following = "pending"
            }
            updatedProfile.followersCount = (currentProfile.followersCount ?? 0) + 1
        }
        self.profile = updatedProfile

        // Now call the API
        do {
            if isFollowing {
                try await client.unfollowUser(followUri: originalProfile.viewer!.following!)
                print("✅ Successfully unfollowed")
            } else {
                _ = try await client.followUser(did: currentProfile.did)
                print("✅ Successfully followed")
            }

            // Optionally refresh from server to get the real follow URI
            // This ensures we have the correct URI for future unfollow operations
            let profiles = try await client.getProfiles(actors: [actor])
            if let serverProfile = profiles.first {
                self.profile = serverProfile
            }
        } catch {
            // Revert optimistic update on error
            self.profile = originalProfile
            errorMessage = isFollowing ? "Failed to unfollow: \(error.localizedDescription)" : "Failed to follow: \(error.localizedDescription)"
            print("❌ Follow action failed, reverted: \(error.localizedDescription)")
        }
    }
}

struct StatView: View {
    let count: Int
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.title3)
                .fontWeight(.bold)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// Pinned post row with pin icon indicator
struct ProfileFeedPostCell: View {
    let feedPost: FeedViewPost
    let currentTime: Date
    let isPinned: Bool
    @Binding var urlToOpen: URL?
    @Binding var profileToShow: String?
    @Binding var hashtagToSearch: String?
    @Binding var postDetailToShow: String?
    @Binding var embeddedPostDetailToShow: String?
    @EnvironmentObject var theme: AppTheme

    private var post: Post { feedPost.post }

    private var postURL: URL {
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
        Button {
            postDetailToShow = post.uri
        } label: {
            postContent
        }
        .buttonStyle(PostCellButtonStyle())
    }

    @ViewBuilder
    private var postContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let reply = feedPost.reply {
                ReplyContextView(
                    replyContext: reply,
                    currentTime: currentTime,
                    profileToShow: $profileToShow,
                    postDetailToShow: $postDetailToShow
                )
                .padding(.bottom, 8)
            }

            if isPinned {
                HStack(spacing: 6) {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(theme.accentColor)
                        .rotationEffect(.degrees(45))
                    Text("Pinned Post")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(theme.accentColor)
                }
            }

            HStack(alignment: .top, spacing: 12) {
                NavigationLink(destination: ProfileView(actor: post.author.safeHandle)) {
                    HStack(spacing: 12) {
                        AvatarImage(
                            url: post.author.avatar.flatMap { URL(string: $0) },
                            size: 48
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(post.author.displayName ?? post.author.safeHandle)
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

            if !post.record.text.isEmpty {
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
            }

            if let images = post.embed?.images, !images.isEmpty {
                ImageGrid(images: images)
            } else if let images = post.embed?.media?.images, !images.isEmpty {
                ImageGrid(images: images)
            }

            if let video = post.embed?.video {
                VideoPlayerView(video: video)
                    .frame(maxHeight: 400)
            } else if let video = post.embed?.media?.video {
                VideoPlayerView(video: video)
                    .frame(maxHeight: 400)
            }

            if let external = post.embed?.external {
                ExternalLinkPreview(external: external, urlToOpen: $urlToOpen)
            }

            if let embeddedRecord = post.embed?.record {
                EmbeddedPostView(
                    record: embeddedRecord,
                    media: nil,
                    currentTime: currentTime,
                    postDetailURI: $embeddedPostDetailToShow
                )
            }

            HStack(spacing: 40) {
                metricView(imageName: "bubble.left", count: post.replyCount)
                metricView(
                    imageName: "arrow.2.squarepath",
                    count: post.repostCount,
                    tint: post.viewer?.repost != nil ? .green : .secondary
                )
                metricView(
                    imageName: post.viewer?.like != nil ? "heart.fill" : "heart",
                    count: post.likeCount,
                    tint: post.viewer?.like != nil ? .pink : .secondary
                )

                Spacer()

                ShareLink(item: postURL) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func metricView(imageName: String, count: Int?, tint: Color = .secondary) -> some View {
        HStack(spacing: 4) {
            Image(systemName: imageName)
                .font(.body)
                .foregroundStyle(tint)
            if let count, count > 0 {
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct SimpleListRow: View {
    let list: ListView

    private var purposeLabel: String {
        guard let lastComponent = list.purpose.split(separator: "#").last else {
            return list.purpose
        }
        let separated = lastComponent
            .replacingOccurrences(of: "list", with: " list")
            .replacingOccurrences(of: "List", with: " List")
        return separated.trimmingCharacters(in: .whitespaces).capitalized
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(list.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(purposeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let description = list.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            if let memberCount = list.listItemCount {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption2)
                    Text("\(memberCount) members")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }

            Text("Created by @\(list.creator.safeHandle)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}

struct SimpleStarterPackRow: View {
    let pack: StarterPack
    @EnvironmentObject var theme: AppTheme

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(pack.record.name)
                    .font(.headline)

                if let description = pack.record.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                if let listItemCount = pack.listItemCount {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.caption)
                        Text("\(listItemCount) members")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationStack {
        ProfileView(actor: "bsky.app")
            .environmentObject(AuthViewModel())
            .environmentObject(AppTheme.shared)
    }
}
