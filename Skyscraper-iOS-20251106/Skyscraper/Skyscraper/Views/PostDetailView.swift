//
//  PostDetailView.swift
//  Skyscraper
//
//  Detailed view of a post with all replies
//

import SwiftUI
import Combine

struct PostDetailView: View {
    let postURI: String

    @StateObject private var viewModel: PostDetailViewModel
    @EnvironmentObject var theme: AppTheme
    @State private var urlToOpen: URL?
    @State private var profileToShow: String?
    @State private var hashtagToSearch: String?
    @State private var currentTime = Date()

    private let timeUpdateTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    init(postURI: String) {
        self.postURI = postURI
        _viewModel = StateObject(wrappedValue: PostDetailViewModel(postURI: postURI))
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: []) {
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                } else if let errorMessage = viewModel.errorMessage {
                    errorView(message: errorMessage)
                } else if let threadPost = viewModel.threadPost {
                    // Show parent context if exists
                    if let parent = threadPost.parent {
                        parentChainView(parent: parent)
                    }

                    // Main post
                    PostDetailCell(
                        post: threadPost.post,
                        isMainPost: true,
                        currentTime: currentTime,
                        urlToOpen: $urlToOpen,
                        profileToShow: $profileToShow,
                        hashtagToSearch: $hashtagToSearch
                    )
                    .environmentObject(viewModel)
                    .background(theme.accentColor.opacity(0.05))

                    Divider()

                    // Replies
                    if let replies = threadPost.replies, !replies.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(replies) { reply in
                                replyView(reply: reply)
                            }

                            // Show "Show more replies" button for client-side pagination
                            if viewModel.canShowMoreReplies() {
                                Button(action: {
                                    viewModel.showMoreReplies()
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.down.circle")
                                        if let fullThread = viewModel.fullThreadPost,
                                           let totalCount = fullThread.replies?.count {
                                            Text("Show more replies (\(replies.count) of \(totalCount))")
                                                .font(.subheadline)
                                        } else {
                                            Text("Show more replies")
                                                .font(.subheadline)
                                        }
                                    }
                                    .foregroundStyle(theme.accentColor)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                }
                                .buttonStyle(.plain)
                            }

                            // Show "Load deeper threads" for server-side loading if needed
                            if viewModel.hasMoreReplies(threadPost) {
                                Button(action: {
                                    Task {
                                        await viewModel.loadMoreReplies(for: threadPost.post.uri)
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        if viewModel.loadingRepliesFor.contains(threadPost.post.uri) {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                        } else {
                                            Image(systemName: "ellipsis")
                                        }
                                        Text("Load nested replies")
                                            .font(.subheadline)
                                    }
                                    .foregroundStyle(theme.accentColor.opacity(0.7))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                }
                                .buttonStyle(.plain)
                                .disabled(viewModel.loadingRepliesFor.contains(threadPost.post.uri))
                            }
                        }
                    } else if viewModel.isLoading == false {
                        Text("No replies yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding()
                    }
                }
            }
        }
        #if os(iOS)
        .background(Color(uiColor: .systemBackground))
        #else
        .background(Color(nsColor: .windowBackgroundColor))
        #endif
        .scrollIndicators(.visible)
        .navigationTitle("Post")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        #endif
        .tint(theme.accentColor)
        .task {
            await viewModel.loadThread()
        }
        .sheet(item: Binding(
            get: { urlToOpen.map { URLWrapper(url: $0) } },
            set: { urlToOpen = $0?.url }
        )) { wrapper in
            SafariView(url: wrapper.url)
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
        .onReceive(timeUpdateTimer) { _ in
            currentTime = Date()
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("Unable to load post")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task { await viewModel.loadThread() }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    private func parentChainView(parent: ThreadViewPost) -> AnyView {
        AnyView(
            VStack(spacing: 0) {
                // Recursively show parent chain
                if let grandparent = parent.parent {
                    parentChainView(parent: grandparent)
                }

                PostDetailCell(
                    post: parent.post,
                    isMainPost: false,
                    currentTime: currentTime,
                    urlToOpen: $urlToOpen,
                    profileToShow: $profileToShow,
                    hashtagToSearch: $hashtagToSearch
                )
                .environmentObject(viewModel)
                .opacity(0.7)

                Divider()
            }
        )
    }

    private func replyView(reply: ThreadViewPost) -> AnyView {
        AnyView(
            VStack(spacing: 0) {
                PostDetailCell(
                    post: reply.post,
                    isMainPost: false,
                    currentTime: currentTime,
                    urlToOpen: $urlToOpen,
                    profileToShow: $profileToShow,
                    hashtagToSearch: $hashtagToSearch
                )
                .environmentObject(viewModel)

                Divider()

                // Show nested replies with indentation
                if let nestedReplies = reply.replies, !nestedReplies.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(nestedReplies) { nestedReply in
                            HStack(spacing: 0) {
                                Color.gray.opacity(0.3)
                                    .frame(width: 2)
                                replyView(reply: nestedReply)
                            }
                        }
                    }
                }

                // Show "Load more replies" button if there are more replies to load
                if viewModel.hasMoreReplies(reply) {
                    HStack(spacing: 0) {
                        Color.gray.opacity(0.3)
                            .frame(width: 2)

                        Button(action: {
                            Task {
                                await viewModel.loadMoreReplies(for: reply.post.uri)
                            }
                        }) {
                            HStack(spacing: 6) {
                                if viewModel.loadingRepliesFor.contains(reply.post.uri) {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "ellipsis")
                                }
                                Text("Load more replies")
                                    .font(.subheadline)
                            }
                            .foregroundStyle(theme.accentColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.loadingRepliesFor.contains(reply.post.uri))
                    }

                    Divider()
                }
            }
        )
    }
}

// MARK: - Post Detail Cell
struct PostDetailCell: View {
    let post: Post
    let isMainPost: Bool
    let currentTime: Date
    @Binding var urlToOpen: URL?
    @Binding var profileToShow: String?
    @Binding var hashtagToSearch: String?
    @State private var embeddedPostDetailURI: String?
    @State private var showingReplyComposer = false
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var viewModel: PostDetailViewModel

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

    private var postURL: URL {
        // Convert at:// URI to https://bsky.app URL
        // Format: at://did:plc:xxx/app.bsky.feed.post/xxx -> https://bsky.app/profile/handle/post/xxx
        let components = post.uri.split(separator: "/")
        if components.count >= 3 {
            let postID = String(components[2])
            let handle = post.author.handle ?? "unknown"
            return URL(string: "https://bsky.app/profile/\(handle)/post/\(postID)")!
        }
        return URL(string: "https://bsky.app")!
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Author info
            HStack(spacing: 12) {
                NavigationLink(destination: ProfileView(actor: post.author.safeHandle)) {
                    HStack(spacing: 12) {
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
                font: isMainPost ? .preferredFont(forTextStyle: .body) : .preferredFont(forTextStyle: .callout),
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
                font: isMainPost ? .systemFont(ofSize: NSFont.systemFontSize) : .systemFont(ofSize: NSFont.smallSystemFontSize),
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
                EmbeddedPostView(record: embeddedRecord, media: nil, currentTime: currentTime, postDetailURI: $embeddedPostDetailURI)
            }

            // Action buttons
            HStack(spacing: 40) {
                Button(action: {
                    showingReplyComposer = true
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
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.2.squarepath").font(.body)
                        if let count = post.repostCount, count > 0 {
                            Text("\(count)").font(.caption)
                        }
                    }.foregroundStyle(post.viewer?.repost != nil ? .green : .secondary)
                }

                Button(action: {
                    Task {
                        await viewModel.toggleLike(for: post)
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
        #if os(iOS)
        .fullScreenCover(isPresented: $showingReplyComposer) {
            PostComposerView(
                replyTo: ReplyRef(
                    root: PostRef(uri: post.uri, cid: post.cid),
                    parent: PostRef(uri: post.uri, cid: post.cid)
                ),
                onPost: { _ in
                    showingReplyComposer = false
                    Task {
                        await viewModel.loadThread()
                    }
                }
            )
        }
        #else
        .sheet(isPresented: $showingReplyComposer) {
            PostComposerView(
                replyTo: ReplyRef(
                    root: PostRef(uri: post.uri, cid: post.cid),
                    parent: PostRef(uri: post.uri, cid: post.cid)
                ),
                onPost: { _ in
                    showingReplyComposer = false
                    Task {
                        await viewModel.loadThread()
                    }
                }
            )
        }
        #endif
        .navigationDestination(item: Binding(
            get: { embeddedPostDetailURI.map { URIWrapper(uri: $0) } },
            set: { embeddedPostDetailURI = $0?.uri }
        )) { wrapper in
            PostDetailView(postURI: wrapper.uri)
        }
    }
}

// MARK: - ViewModel
@MainActor
class PostDetailViewModel: ObservableObject {
    @Published var threadPost: ThreadViewPost?
    @Published var fullThreadPost: ThreadViewPost?  // Store full thread for pagination
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var loadingRepliesFor = Set<String>()
    @Published var visibleReplyCount: Int = 10  // Show only 10 replies initially
    @Published var isLoadingMore = false

    private let postURI: String
    private let client = ATProtoClient.shared
    private let initialDepth = 1  // Load only 1 level initially for fastest display
    private let expandDepth = 3   // Load 3 levels in background (reduced from 6)
    private let replyBatchSize = 20  // Load 20 more replies at a time

    init(postURI: String) {
        self.postURI = postURI
    }

    func loadThread() async {
        isLoading = true
        errorMessage = nil

        do {
            // Load with minimal depth for fastest initial display
            let response = try await client.getPostThread(uri: postURI, depth: initialDepth)
            threadPost = response.thread
            fullThreadPost = response.thread

            // Start background loading of deeper replies after a short delay
            Task {
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 second delay
                await loadDeeperRepliesInBackground()
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func loadDeeperRepliesInBackground() async {
        // Load the full thread in the background to get all replies
        do {
            let response = try await client.getPostThread(uri: postURI, depth: expandDepth)
            // Only update if we're still viewing the same thread
            if threadPost?.post.uri == response.thread.post.uri {
                fullThreadPost = response.thread
                // Update threadPost with limited visible replies
                threadPost = limitReplies(response.thread, maxReplies: visibleReplyCount)
            }
        } catch {
            print("Background thread loading failed: \(error)")
        }
    }

    func showMoreReplies() {
        visibleReplyCount += replyBatchSize
        if let full = fullThreadPost {
            threadPost = limitReplies(full, maxReplies: visibleReplyCount)
        }
    }

    func canShowMoreReplies() -> Bool {
        guard let thread = threadPost, let fullThread = fullThreadPost else { return false }
        let currentCount = thread.replies?.count ?? 0
        let totalCount = fullThread.replies?.count ?? 0
        return currentCount < totalCount
    }

    private func limitReplies(_ thread: ThreadViewPost, maxReplies: Int) -> ThreadViewPost {
        switch thread {
        case .post(let post, let parent, let replies):
            let limitedReplies = replies.map { Array($0.prefix(maxReplies)) }
            return .post(post: post, parent: parent, replies: limitedReplies)
        }
    }

    func loadMoreReplies(for postUri: String) async {
        // Prevent duplicate loads
        guard !loadingRepliesFor.contains(postUri) else { return }

        loadingRepliesFor.insert(postUri)

        do {
            // Fetch this specific post's thread with deeper nesting
            let response = try await client.getPostThread(uri: postUri, depth: expandDepth)

            // Merge the new replies into both the displayed and full thread
            if let currentThread = threadPost {
                threadPost = mergeReplies(into: currentThread, from: response.thread, forPostUri: postUri)
            }
            if let currentFullThread = fullThreadPost {
                fullThreadPost = mergeReplies(into: currentFullThread, from: response.thread, forPostUri: postUri)
            }
        } catch {
            print("Failed to load more replies: \(error)")
        }

        loadingRepliesFor.remove(postUri)
    }

    private func mergeReplies(into existing: ThreadViewPost, from new: ThreadViewPost, forPostUri: String) -> ThreadViewPost {
        switch existing {
        case .post(let post, let parent, let replies):
            // If this is the post we're expanding, use the new replies
            if post.uri == forPostUri {
                return .post(post: post, parent: parent, replies: new.replies)
            }

            // Otherwise, recursively search and update in the tree
            let updatedReplies = replies?.map { reply in
                mergeReplies(into: reply, from: new, forPostUri: forPostUri)
            }

            return .post(post: post, parent: parent, replies: updatedReplies)
        }
    }

    func hasMoreReplies(_ threadPost: ThreadViewPost) -> Bool {
        let post = threadPost.post
        let loadedRepliesCount = threadPost.replies?.count ?? 0
        let totalRepliesCount = post.replyCount ?? 0

        // Check if there are more replies than what we've loaded
        return totalRepliesCount > loadedRepliesCount && loadedRepliesCount > 0
    }

    func toggleLike(for post: Post) async {
        let wasLiked = post.viewer?.like != nil

        // Optimistically update UI
        if let thread = threadPost {
            threadPost = updatePostInTree(thread, postUri: post.uri) { updatedPost in
                var mutablePost = updatedPost
                if wasLiked {
                    mutablePost.viewer?.like = nil
                    mutablePost.likeCount = max((mutablePost.likeCount ?? 0) - 1, 0)
                } else {
                    if mutablePost.viewer == nil {
                        mutablePost.viewer = PostViewer(like: "temp", repost: nil, bookmarked: nil, threadMuted: nil, replyDisabled: nil, embeddingDisabled: nil)
                    } else {
                        mutablePost.viewer?.like = "temp"
                    }
                    mutablePost.likeCount = (mutablePost.likeCount ?? 0) + 1
                }
                return mutablePost
            }
        }

        // Make API call in background
        do {
            if let likeUri = post.viewer?.like {
                try await client.unlikePost(likeUri: likeUri)
            } else {
                let likeUri = try await client.likePost(uri: post.uri, cid: post.cid)

                // Update with real like URI
                if let thread = threadPost {
                    threadPost = updatePostInTree(thread, postUri: post.uri) { updatedPost in
                        var mutablePost = updatedPost
                        if mutablePost.viewer == nil {
                            mutablePost.viewer = PostViewer(like: likeUri, repost: nil, bookmarked: nil, threadMuted: nil, replyDisabled: nil, embeddingDisabled: nil)
                        } else {
                            mutablePost.viewer?.like = likeUri
                        }
                        return mutablePost
                    }
                }
            }
        } catch {
            print("Failed to toggle like: \(error)")
            // Revert on error
            await loadThread()
        }
    }

    func toggleRepost(for post: Post) async {
        let wasReposted = post.viewer?.repost != nil

        // Optimistically update UI
        if let thread = threadPost {
            threadPost = updatePostInTree(thread, postUri: post.uri) { updatedPost in
                var mutablePost = updatedPost
                if wasReposted {
                    // Unrepost
                    mutablePost.viewer?.repost = nil
                    mutablePost.repostCount = max(0, (mutablePost.repostCount ?? 0) - 1)
                } else {
                    // Repost
                    if mutablePost.viewer == nil {
                        mutablePost.viewer = PostViewer(like: nil, repost: "temp", bookmarked: nil, threadMuted: nil, replyDisabled: nil, embeddingDisabled: nil)
                    } else {
                        mutablePost.viewer?.repost = "temp"
                    }
                    mutablePost.repostCount = (mutablePost.repostCount ?? 0) + 1
                }
                return mutablePost
            }
        }

        // Make API call in background
        do {
            if wasReposted {
                try await client.unrepost(repostUri: post.viewer!.repost!)
                print("✅ Successfully unreposted")
            } else {
                let repostUri = try await client.repost(uri: post.uri, cid: post.cid)
                print("✅ Successfully reposted, URI: \(repostUri)")

                // Update with real repost URI
                if let thread = threadPost {
                    threadPost = updatePostInTree(thread, postUri: post.uri) { updatedPost in
                        var mutablePost = updatedPost
                        if mutablePost.viewer == nil {
                            mutablePost.viewer = PostViewer(like: nil, repost: repostUri, bookmarked: nil, threadMuted: nil, replyDisabled: nil, embeddingDisabled: nil)
                        } else {
                            mutablePost.viewer?.repost = repostUri
                        }
                        return mutablePost
                    }
                }
            }
        } catch {
            print("Failed to \(wasReposted ? "unrepost" : "repost"): \(error)")
            // Revert on error
            await loadThread()
        }
    }

    private func updatePostInTree(_ thread: ThreadViewPost, postUri: String, update: (Post) -> Post) -> ThreadViewPost {
        switch thread {
        case .post(let post, let parent, let replies):
            // Check if this is the post we want to update
            if post.uri == postUri {
                return .post(post: update(post), parent: parent, replies: replies)
            }

            // Update parent chain if needed
            let updatedParent = parent.map { updatePostInTree($0, postUri: postUri, update: update) }

            // Update replies if needed
            let updatedReplies = replies?.map { updatePostInTree($0, postUri: postUri, update: update) }

            return .post(post: post, parent: updatedParent, replies: updatedReplies)
        }
    }
}
