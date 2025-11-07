//
//  FeedBrowserView.swift
//  Skyscraper
//
//  Browse and discover custom feeds
//

import SwiftUI
import Combine

struct FeedBrowserView: View {
    @StateObject private var viewModel = FeedBrowserViewModel()
    @EnvironmentObject var theme: AppTheme
    @State private var searchText = ""

    var filteredFeeds: [FeedGenerator] {
        if searchText.isEmpty {
            return viewModel.feeds
        } else {
            return viewModel.feeds.filter { feed in
                feed.displayName.localizedCaseInsensitiveContains(searchText) ||
                (feed.description?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                feed.creator.safeHandle.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Always visible search bar
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField("Search feeds", text: $searchText)
                        .textFieldStyle(.plain)

                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                #if os(iOS)
                .background(Color(.systemGray6))
                #else
                .background(Color(nsColor: .controlBackgroundColor))
                #endif
                .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            if viewModel.isLoading && viewModel.feeds.isEmpty {
                ProgressView("Loading feeds...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = viewModel.errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text("Unable to load feeds")
                        .font(.headline)
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Try Again") {
                        Task { await viewModel.loadFeeds() }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredFeeds) { feed in
                        NavigationLink(destination: FeedPreviewView(feedGenerator: feed)) {
                            FeedRow(feed: feed, viewModel: viewModel)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Browse Feeds")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .refreshable {
            await viewModel.loadFeeds()
        }
        .task {
            if viewModel.feeds.isEmpty {
                await viewModel.loadFeeds()
            }
        }
    }
}

struct FeedRow: View {
    let feed: FeedGenerator
    @ObservedObject var viewModel: FeedBrowserViewModel
    @EnvironmentObject var theme: AppTheme

    var isSaved: Bool {
        viewModel.savedFeedURIs.contains(feed.uri)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Feed avatar
                if let avatarURL = feed.avatar.flatMap({ URL(string: $0) }) {
                    AvatarImage(url: avatarURL, size: 50)
                } else {
                    Circle()
                        .fill(theme.accentColor.opacity(0.2))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .foregroundStyle(theme.accentColor)
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(feed.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text("by @\(feed.creator.handle ?? "unknown")")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let likeCount = feed.likeCount, likeCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.caption2)
                            Text("\(likeCount)")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button(action: {
                    Task {
                        await viewModel.toggleSaveFeed(feed.uri)
                    }
                }) {
                    if viewModel.isTogglingFeed == feed.uri {
                        ProgressView()
                            .frame(width: 70)
                    } else {
                        Text(isSaved ? "Saved" : "Save")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(isSaved ? .white : theme.accentColor)
                            .frame(width: 70)
                            .padding(.vertical, 8)
                            .background(isSaved ? theme.accentColor : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(theme.accentColor, lineWidth: isSaved ? 0 : 1)
                            )
                            .cornerRadius(8)
                    }
                }
                .buttonStyle(.plain)
            }

            if let description = feed.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 8)
    }
}

@MainActor
class FeedBrowserViewModel: ObservableObject {
    @Published var feeds: [FeedGenerator] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var savedFeedURIs: Set<String> = []
    @Published var isTogglingFeed: String?

    private let client = ATProtoClient.shared
    private var currentPreferences: [Preference] = []

    func loadFeeds() async {
        isLoading = true
        errorMessage = nil

        do {
            // Load suggested feeds with maximum allowed limit (100)
            // Note: Bluesky API doesn't have a dedicated feed search endpoint,
            // so we load suggested feeds and filter locally
            let response = try await client.getSuggestedFeeds(limit: 100)

            // Sort by popularity (likeCount)
            feeds = response.feeds.sorted { ($0.likeCount ?? 0) > ($1.likeCount ?? 0) }

            // Load current preferences to know which feeds are saved
            await loadSavedFeeds()

            print("✅ Loaded \(feeds.count) feeds for browsing")
        } catch {
            errorMessage = error.localizedDescription
            print("Failed to load feeds: \(error)")
        }

        isLoading = false
    }

    func loadSavedFeeds() async {
        do {
            let preferencesResponse = try await client.getPreferences()
            currentPreferences = preferencesResponse.preferences

            // Extract saved feed URIs
            for preference in preferencesResponse.preferences {
                if case .savedFeeds(let savedFeeds) = preference {
                    savedFeedURIs = Set(savedFeeds.saved)
                    break
                }
            }
        } catch {
            print("Failed to load saved feeds: \(error)")
        }
    }

    func toggleSaveFeed(_ feedURI: String) async {
        isTogglingFeed = feedURI

        do {
            var newSaved = Array(savedFeedURIs)

            if savedFeedURIs.contains(feedURI) {
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
                    // Update existing saved feeds preference
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

            // If no saved feeds pref exists, create one
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
            savedFeedURIs = Set(newSaved)

            // Track analytics
            let action = savedFeedURIs.contains(feedURI) ? "save" : "unsave"
            Analytics.logEvent("feed_interaction", parameters: [
                "action": action,
                "feed_uri": feedURI
            ])
            print("📊 Analytics: Logged feed_interaction (\(action))")
            print("✅ Successfully \(savedFeedURIs.contains(feedURI) ? "saved" : "removed") feed")
        } catch {
            print("Failed to toggle feed: \(error)")
            errorMessage = "Failed to update feed. Please try again."
        }

        isTogglingFeed = nil
    }
}

#Preview {
    NavigationStack {
        FeedBrowserView()
    }
}
