//
//  FeedPreviewView.swift
//  Skyscraper
//
//  Feed preview view - shows posts from a feed before saving/following
//

import SwiftUI
import Combine

struct FeedPreviewView: View {
    let feedGenerator: FeedGenerator
    @StateObject private var viewModel: FeedPreviewViewModel
    @EnvironmentObject var theme: AppTheme
    @State private var urlToOpen: URL?
    @State private var profileToShow: String?
    @State private var hashtagToSearch: String?
    @State private var postDetailToShow: String?
    @State private var currentTime = Date()

    private let timeUpdateTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    init(feedGenerator: FeedGenerator) {
        self.feedGenerator = feedGenerator
        _viewModel = StateObject(wrappedValue: FeedPreviewViewModel(feedURI: feedGenerator.uri))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Feed header
            feedHeader

            Divider()

            // Posts content
            if viewModel.isLoading && viewModel.posts.isEmpty {
                loadingView
            } else if let errorMessage = viewModel.errorMessage, viewModel.posts.isEmpty {
                errorView(message: errorMessage)
            } else if viewModel.posts.isEmpty {
                emptyView
            } else {
                postsListView
            }
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
        .navigationDestination(item: Binding(
            get: { postDetailToShow.map { URIWrapper(uri: $0) } },
            set: { postDetailToShow = $0?.uri }
        )) { wrapper in
            PostDetailView(postURI: wrapper.uri)
        }
        .task {
            await viewModel.loadPosts()
        }
        .refreshable {
            await viewModel.refresh()
        }
        .onReceive(timeUpdateTimer) { _ in
            currentTime = Date()
        }
    }

    // MARK: - Subviews

    private var feedHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Feed avatar
                if let avatarURL = feedGenerator.avatar.flatMap({ URL(string: $0) }) {
                    AvatarImage(url: avatarURL, size: 60)
                } else {
                    Circle()
                        .fill(theme.accentColor.opacity(0.2))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.title2)
                                .foregroundStyle(theme.accentColor)
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(feedGenerator.displayName)
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text("by @\(feedGenerator.creator.handle ?? "unknown")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let likeCount = feedGenerator.likeCount, likeCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.caption)
                            Text("\(likeCount)")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }

            if let description = feedGenerator.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Save/Saved button
            Button(action: {
                Task {
                    await viewModel.toggleSaveFeed()
                }
            }) {
                HStack {
                    if viewModel.isTogglingFeed {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(viewModel.isSaved ? "Saved" : "Save Feed")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(viewModel.isSaved ? .white : theme.accentColor)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 12)
                .background(viewModel.isSaved ? theme.accentColor : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(theme.accentColor, lineWidth: viewModel.isSaved ? 0 : 2)
                )
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isTogglingFeed)
        }
        .padding()
    }

    private var loadingView: some View {
        VStack {
            ProgressView()
            Text("Loading feed preview...")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
        .frame(maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                Text("Unable to load feed")
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
            .padding()
        }
    }

    private var emptyView: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "tray")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("No posts yet")
                    .font(.headline)
                Text("This feed doesn't have any posts yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }

    private var postsListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.posts) { feedPost in
                    PostCell(
                        feedPost: feedPost,
                        viewModel: viewModel.timelineViewModel,
                        currentTime: currentTime,
                        urlToOpen: $urlToOpen,
                        profileToShow: $profileToShow,
                        hashtagToSearch: $hashtagToSearch,
                        postDetailToShow: $postDetailToShow,
                        embeddedPostDetailToShow: .constant(nil)
                    )
                    .id(feedPost.id)

                    Divider()
                }

                // Load more indicator
                if viewModel.hasMore && !viewModel.isLoadingMore {
                    Color.clear
                        .frame(height: 1)
                        .onAppear {
                            Task {
                                await viewModel.loadMore()
                            }
                        }
                } else if viewModel.isLoadingMore {
                    ProgressView()
                        .padding()
                }
            }
        }
    }
}

// MARK: - ViewModel

@MainActor
class FeedPreviewViewModel: ObservableObject {
    @Published var posts: [FeedViewPost] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var hasMore = true
    @Published var isSaved = false
    @Published var isTogglingFeed = false

    let feedURI: String
    private var cursor: String?
    private let client = ATProtoClient.shared
    private var currentPreferences: [Preference] = []

    // TimelineViewModel for PostCell interactions
    let timelineViewModel = TimelineViewModel()

    init(feedURI: String) {
        self.feedURI = feedURI
    }

    func loadPosts() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            // Load feed posts
            let response = try await client.getFeed(feed: feedURI, limit: 30)
            posts = response.feed
            cursor = response.cursor
            hasMore = response.cursor != nil

            // Check if feed is saved
            await checkIfSaved()

            print("✅ Loaded \(posts.count) posts for feed preview")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Failed to load feed preview: \(error)")
        }

        isLoading = false
    }

    func refresh() async {
        cursor = nil
        hasMore = true
        await loadPosts()
    }

    func loadMore() async {
        guard !isLoadingMore, hasMore, let cursor = cursor else { return }

        isLoadingMore = true

        do {
            let response = try await client.getFeed(feed: feedURI, limit: 30, cursor: cursor)
            posts.append(contentsOf: response.feed)
            self.cursor = response.cursor
            hasMore = response.cursor != nil

            print("✅ Loaded \(response.feed.count) more posts")
        } catch {
            print("❌ Failed to load more posts: \(error)")
        }

        isLoadingMore = false
    }

    func checkIfSaved() async {
        do {
            let preferencesResponse = try await client.getPreferences()
            currentPreferences = preferencesResponse.preferences

            for preference in preferencesResponse.preferences {
                if case .savedFeeds(let savedFeeds) = preference {
                    isSaved = savedFeeds.saved.contains(feedURI)
                    break
                }
            }
        } catch {
            print("❌ Failed to check if feed is saved: \(error)")
        }
    }

    func toggleSaveFeed() async {
        isTogglingFeed = true

        do {
            var savedFeedURIs = Set<String>()

            // Get current saved feeds
            for preference in currentPreferences {
                if case .savedFeeds(let savedFeeds) = preference {
                    savedFeedURIs = Set(savedFeeds.saved)
                    break
                }
            }

            var newSaved = Array(savedFeedURIs)

            if isSaved {
                // Remove from saved
                newSaved.removeAll { $0 == feedURI }
            } else {
                // Add to saved
                newSaved.append(feedURI)
            }

            // Find existing SavedFeedsPref or create new one
            var updatedPreferences = currentPreferences
            var foundSavedFeedsPref = false

            for (index, preference) in currentPreferences.enumerated() {
                if case .savedFeeds(let savedFeeds) = preference {
                    var newPinned = savedFeeds.pinned
                    // If we're removing a feed, also remove it from pinned
                    if !newSaved.contains(feedURI) {
                        newPinned.removeAll { $0 == feedURI }
                    }

                    updatedPreferences[index] = .savedFeeds(SavedFeedsPref(
                        pinned: newPinned,
                        saved: newSaved
                    ))
                    foundSavedFeedsPref = true
                    break
                }
            }

            if !foundSavedFeedsPref {
                updatedPreferences.append(.savedFeeds(SavedFeedsPref(
                    pinned: [],
                    saved: newSaved
                )))
            }

            // Save to server
            try await client.putPreferences(preferences: updatedPreferences)

            // Update local state
            currentPreferences = updatedPreferences
            isSaved = !isSaved

            // Track analytics
            let action = isSaved ? "save" : "unsave"
            Analytics.logEvent("feed_interaction", parameters: [
                "action": action,
                "feed_uri": feedURI,
                "source": "preview"
            ])

            print("✅ Successfully \(isSaved ? "saved" : "removed") feed from preview")
        } catch {
            print("❌ Failed to toggle feed: \(error)")
            errorMessage = "Failed to update feed. Please try again."
        }

        isTogglingFeed = false
    }
}

#Preview {
    NavigationStack {
        FeedPreviewView(feedGenerator: FeedGenerator(
            uri: "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.generator/whats-hot",
            cid: "bafyreib3ffl2teiqdncv3mkbth4fo",
            did: "did:plc:z72i7hdynmk6r22z27h6tvur",
            creator: Author(
                did: "did:plc:z72i7hdynmk6r22z27h6tvur",
                handle: "bsky.app",
                displayName: "Bluesky",
                description: nil,
                avatar: nil,
                associated: nil,
                viewer: nil,
                labels: nil,
                createdAt: nil
            ),
            displayName: "What's Hot",
            description: "The most popular posts from around Bluesky",
            avatar: nil,
            likeCount: 10000,
            indexedAt: "2024-01-01T00:00:00.000Z"
        ))
    }
    .environmentObject(AppTheme.shared)
}
