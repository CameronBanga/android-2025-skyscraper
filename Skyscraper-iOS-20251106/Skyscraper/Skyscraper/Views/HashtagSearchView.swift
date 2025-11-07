//
//  HashtagSearchView.swift
//  Skyscraper
//
//  Search for posts by hashtag
//

import SwiftUI
import Combine

struct HashtagSearchView: View {
    let hashtag: String
    @StateObject private var viewModel: HashtagSearchViewModel
    @State private var urlToOpen: URL?
    @State private var profileToShow: String?
    @State private var hashtagToSearch: String?
    @State private var currentTime = Date()

    private let timeUpdateTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    init(hashtag: String) {
        self.hashtag = hashtag
        _viewModel = StateObject(wrappedValue: HashtagSearchViewModel(hashtag: hashtag))
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if viewModel.isLoading && viewModel.posts.isEmpty {
                    ProgressView()
                        .padding()
                } else if let errorMessage = viewModel.errorMessage, viewModel.posts.isEmpty {
                    errorView(message: errorMessage)
                } else if viewModel.posts.isEmpty {
                    emptyView
                } else {
                    ForEach(viewModel.posts) { feedPost in
                        HashtagPostCell(
                            feedPost: feedPost,
                            currentTime: currentTime,
                            urlToOpen: $urlToOpen,
                            profileToShow: $profileToShow,
                            hashtagToSearch: $hashtagToSearch
                        )
                        Divider()
                    }

                    if viewModel.cursor != nil {
                        ProgressView()
                            .padding()
                            .onAppear {
                                Task { await viewModel.loadMore() }
                            }
                    }
                }
            }
        }
        .navigationTitle("#\(hashtag)")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            await viewModel.searchPosts()
        }
        .refreshable {
            await viewModel.refresh()
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
            Text("Unable to search")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task { await viewModel.searchPosts() }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "number")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No posts found")
                .font(.headline)
            Text("No posts found with #\(hashtag)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

// MARK: - Hashtag Post Cell
struct HashtagPostCell: View {
    let feedPost: FeedViewPost
    let currentTime: Date
    @Binding var urlToOpen: URL?
    @Binding var profileToShow: String?
    @Binding var hashtagToSearch: String?
    @State private var embeddedPostDetailURI: String?
    @EnvironmentObject var theme: AppTheme

    var post: Post {
        feedPost.post
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

    private var postURL: URL {
        // Convert at:// URI to https://bsky.app URL
        let components = post.uri.split(separator: "/")
        if components.count >= 3 {
            let postID = String(components[2])
            return URL(string: "https://bsky.app/profile/\(post.author.safeHandle)/post/\(postID)")!
        }
        return URL(string: "https://bsky.app")!
    }

    var body: some View {
        NavigationLink(destination: PostDetailView(postURI: post.uri)) {
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

                // External link preview if present
                if let external = post.embed?.external {
                    ExternalLinkPreview(external: external, urlToOpen: $urlToOpen)
                }

                // Embedded/quoted post if present
                if let embeddedRecord = post.embed?.record {
                    // Don't pass media - it belongs to the parent post, not the embedded post
                    EmbeddedPostView(record: embeddedRecord, media: nil, currentTime: currentTime, postDetailURI: $embeddedPostDetailURI)
                }

                // Stats
                HStack(spacing: 24) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left")
                        if let count = post.replyCount, count > 0 {
                            Text("\(count)")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        Image(systemName: "arrow.2.squarepath")
                        if let count = post.repostCount, count > 0 {
                            Text("\(count)")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        Image(systemName: post.viewer?.like != nil ? "heart.fill" : "heart")
                        if let count = post.likeCount, count > 0 {
                            Text("\(count)")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(post.viewer?.like != nil ? .pink : .secondary)

                    Spacer()

                    ShareLink(item: postURL) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
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
class HashtagSearchViewModel: ObservableObject {
    @Published var posts: [FeedViewPost] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var cursor: String?

    private let hashtag: String
    private let client = ATProtoClient.shared

    init(hashtag: String) {
        self.hashtag = hashtag
    }

    func searchPosts() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await client.searchPosts(query: "#\(hashtag)", limit: 50)
            // Convert Post objects to FeedViewPost objects
            posts = response.posts.map { post in
                FeedViewPost(post: post, reply: nil, reason: nil)
            }
            cursor = response.cursor
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func refresh() async {
        cursor = nil
        await searchPosts()
    }

    func loadMore() async {
        guard let cursor = cursor, !isLoading else { return }

        isLoading = true

        do {
            let response = try await client.searchPosts(query: "#\(hashtag)", cursor: cursor, limit: 50)
            // Convert Post objects to FeedViewPost objects
            let newPosts = response.posts.map { post in
                FeedViewPost(post: post, reply: nil, reason: nil)
            }
            posts.append(contentsOf: newPosts)
            self.cursor = response.cursor
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
