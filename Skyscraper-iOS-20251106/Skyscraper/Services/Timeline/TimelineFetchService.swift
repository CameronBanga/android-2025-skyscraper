//
//  TimelineFetchService.swift
//  Skyscraper
//
//  Protocol for fetching timeline posts
//

import Foundation

/// Service responsible for fetching timeline and feed posts
protocol TimelineFetchService {
    /// Fetch timeline posts (following feed)
    func fetchTimeline(limit: Int, cursor: String?) async throws -> FeedResponse

    /// Fetch custom feed posts
    func fetchFeed(uri: String, limit: Int, cursor: String?) async throws -> FeedResponse

    /// Fetch available feeds for the current user
    func fetchAvailableFeeds() async throws -> [FeedInfo]
}

/// Default implementation using ATProtoClient
@MainActor
class DefaultTimelineFetchService: TimelineFetchService {
    private let client: ATProtoClient

    init(client: ATProtoClient? = nil) {
        self.client = client ?? ATProtoClient.shared
    }

    func fetchTimeline(limit: Int, cursor: String?) async throws -> FeedResponse {
        try await client.getTimeline(limit: limit, cursor: cursor)
    }

    func fetchFeed(uri: String, limit: Int, cursor: String?) async throws -> FeedResponse {
        try await client.getFeed(feed: uri, limit: limit, cursor: cursor)
    }

    func fetchAvailableFeeds() async throws -> [FeedInfo] {
        // Get user's saved/pinned feeds from preferences
        guard client.session != nil else {
            return [FeedInfo.following]
        }

        var feeds: [FeedInfo] = [FeedInfo.following]

        do {
            // Get user preferences which include saved feeds
            let prefsResponse = try await client.getPreferences()

            // Find the saved feeds preference
            var savedFeedURIs: [String] = []
            for pref in prefsResponse.preferences {
                if case .savedFeeds(let savedFeedsPref) = pref {
                    // Include both pinned and saved feeds, removing duplicates while preserving order
                    // A feed can be in both pinned and saved arrays
                    var seen = Set<String>()
                    var unique: [String] = []

                    for uri in savedFeedsPref.pinned + savedFeedsPref.saved {
                        if !seen.contains(uri) {
                            seen.insert(uri)
                            unique.append(uri)
                        }
                    }

                    savedFeedURIs = unique
                    break
                }
            }

            // If we have saved feeds, fetch their details
            if !savedFeedURIs.isEmpty {
                let generatorsResponse = try await client.getFeedGenerators(feeds: savedFeedURIs)

                for generator in generatorsResponse.feeds {
                    let feed = FeedInfo(
                        id: generator.uri,
                        uri: generator.uri,
                        displayName: generator.displayName,
                        description: generator.description,
                        avatar: generator.avatar
                    )
                    feeds.append(feed)
                }
            }
        } catch {
            AppLogger.warning("Failed to load saved feeds, using Following only: \(error.localizedDescription)", subsystem: "Feed")
            // Return at least Following feed on error
            return [FeedInfo.following]
        }

        return feeds
    }
}
