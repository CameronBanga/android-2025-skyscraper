//
//  DiscoverViewModel.swift
//  Skyscraper
//
//  Manages discovery of suggested users
//

import Foundation
import Combine

@MainActor
class DiscoverViewModel: ObservableObject {
    @Published var suggestedUsers: [Profile] = []
    @Published var trendingTopics: [TrendingTopic] = []
    @Published var isLoading = false
    @Published var isLoadingTopics = false
    @Published var errorMessage: String?

    private let client = ATProtoClient.shared

    // List of interesting accounts to suggest
    private let suggestedHandles = [
        "cameronbanga.com",
        "giantbomb.bsky.social",
        "jeffgerstmann.com",
        "kenwhite.bsky.social",
        "frailgesture.bsky.social",
        "bsky.app",
        "atproto.com"
    ]

    func loadSuggestions() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        // Load trending topics and suggested users in parallel
        async let topicsTask: () = loadTrendingTopics()
        async let usersTask: () = loadUsers()

        await topicsTask
        await usersTask

        isLoading = false
    }

    private func loadTrendingTopics() async {
        isLoadingTopics = true

        do {
            let response = try await client.getTrendingTopics(limit: 10)
            trendingTopics = response.topics
            print("✅ Loaded \(trendingTopics.count) trending topics")
        } catch {
            print("❌ Failed to load trending topics: \(error)")
        }

        isLoadingTopics = false
    }

    private func loadUsers() async {
        var profiles: [Profile] = []
        var failedHandles: [String] = []

        for handle in suggestedHandles {
            // Basic validation: ensure handle looks reasonable
            guard !handle.isEmpty && handle.contains(".") else {
                print("⚠️ Skipping invalid handle format: '\(handle)'")
                failedHandles.append(handle)
                continue
            }

            do {
                let profile = try await client.getProfile(actor: handle)
                profiles.append(profile)
                print("✅ Loaded profile for @\(handle)")
            } catch {
                // Log the failure but continue loading other profiles
                print("⚠️ Failed to load profile for @\(handle): \(error.localizedDescription)")
                failedHandles.append(handle)
            }
        }

        suggestedUsers = profiles

        // Log summary
        if !failedHandles.isEmpty {
            print("⚠️ Failed to load \(failedHandles.count) profiles: \(failedHandles.joined(separator: ", "))")
            print("💡 Consider removing these handles from suggestedHandles list")
        }
    }
}
