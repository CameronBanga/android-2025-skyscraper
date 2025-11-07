//
//  PostCacheService.swift
//  Skyscraper
//
//  Service for caching and retrieving timeline posts
//

import Foundation
import CoreData

@MainActor
class PostCacheService {
    static let shared = PostCacheService()

    private let coreData = CoreDataStack.shared
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // Save posts to cache for a specific feed
    func cachePosts(_ posts: [FeedViewPost], feedId: String) {
        let context = coreData.context

        for (index, feedPost) in posts.enumerated() {
            // Check if post already exists for this feed
            let fetchRequest = NSFetchRequest<CachedPost>(entityName: "CachedPost")
            fetchRequest.predicate = NSPredicate(format: "uri == %@ AND feedId == %@", feedPost.post.uri, feedId)
            fetchRequest.fetchLimit = 1

            do {
                let existing = try context.fetch(fetchRequest)

                if existing.isEmpty {
                    // Create new cached post
                    let cachedPost = CachedPost(context: context)
                    cachedPost.uri = feedPost.post.uri
                    cachedPost.feedId = feedId
                    cachedPost.jsonData = try encoder.encode(feedPost)
                    cachedPost.cachedAt = Date()
                    cachedPost.createdAt = feedPost.post.createdAt
                    cachedPost.sortOrder = Int64(index)

                    print("Cached post: \(feedPost.post.uri) for feed: \(feedId)")
                } else {
                    // Update existing
                    let cachedPost = existing[0]
                    cachedPost.jsonData = try encoder.encode(feedPost)
                    cachedPost.cachedAt = Date()
                    cachedPost.sortOrder = Int64(index)
                }
            } catch {
                print("Error caching post: \(error.localizedDescription)")
            }
        }

        coreData.saveContext()
    }

    // Load cached posts for a specific feed
    func loadCachedPosts(feedId: String) -> [FeedViewPost] {
        let context = coreData.context

        let fetchRequest = NSFetchRequest<CachedPost>(entityName: "CachedPost")
        fetchRequest.predicate = NSPredicate(format: "feedId == %@", feedId)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        do {
            let cachedPosts = try context.fetch(fetchRequest)
            print("Loaded \(cachedPosts.count) cached posts for feed: \(feedId)")

            return cachedPosts.compactMap { cached in
                do {
                    return try decoder.decode(FeedViewPost.self, from: cached.jsonData)
                } catch {
                    print("Error decoding cached post: \(error.localizedDescription)")
                    return nil
                }
            }
        } catch {
            print("Error loading cached posts: \(error.localizedDescription)")
            return []
        }
    }

    // Load all cached posts across all feeds (for cache size calculation)
    func loadAllCachedPosts() -> [FeedViewPost] {
        let context = coreData.context

        let fetchRequest = NSFetchRequest<CachedPost>(entityName: "CachedPost")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        do {
            let cachedPosts = try context.fetch(fetchRequest)
            print("Loaded \(cachedPosts.count) total cached posts across all feeds")

            return cachedPosts.compactMap { cached in
                do {
                    return try decoder.decode(FeedViewPost.self, from: cached.jsonData)
                } catch {
                    print("Error decoding cached post: \(error.localizedDescription)")
                    return nil
                }
            }
        } catch {
            print("Error loading cached posts: \(error.localizedDescription)")
            return []
        }
    }

    // Clear all cached posts
    func clearCache() {
        let context = coreData.context
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "CachedPost")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

        do {
            try context.execute(deleteRequest)
            coreData.saveContext()
            print("Cache cleared")
        } catch {
            print("Error clearing cache: \(error.localizedDescription)")
        }
    }

    // Clean up old posts (10 days)
    func cleanupOldPosts() {
        coreData.clearOldPosts(olderThan: 10)
    }

    // Save scroll position for a specific feed
    func saveScrollPosition(postURI: String, forFeed feedID: String) {
        var positions = loadAllScrollPositions()
        positions[feedID] = postURI

        if let encoded = try? JSONEncoder().encode(positions) {
            UserDefaults.standard.set(encoded, forKey: "feedScrollPositions")
            print("Saved scroll position for feed \(feedID): \(postURI)")
        }
    }

    // Load scroll position for a specific feed
    func loadScrollPosition(forFeed feedID: String) -> String? {
        let positions = loadAllScrollPositions()
        return positions[feedID]
    }

    // Load all scroll positions
    private func loadAllScrollPositions() -> [String: String] {
        guard let data = UserDefaults.standard.data(forKey: "feedScrollPositions"),
              let positions = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return positions
    }

    // Clear scroll position for a specific feed
    func clearScrollPosition(forFeed feedID: String) {
        var positions = loadAllScrollPositions()
        positions.removeValue(forKey: feedID)

        if let encoded = try? JSONEncoder().encode(positions) {
            UserDefaults.standard.set(encoded, forKey: "feedScrollPositions")
        }
    }

    // Clear all scroll positions
    func clearAllScrollPositions() {
        UserDefaults.standard.removeObject(forKey: "feedScrollPositions")
    }

    // MARK: - Last Viewed Timestamp

    /// Save the last viewed timestamp for a feed (when user has seen posts up to this time)
    func saveLastViewedTimestamp(_ timestamp: Date, forFeed feedID: String) {
        var timestamps = loadAllLastViewedTimestamps()
        timestamps[feedID] = timestamp

        if let encoded = try? JSONEncoder().encode(timestamps) {
            UserDefaults.standard.set(encoded, forKey: "feedLastViewedTimestamps")
            print("💾 Saved last viewed timestamp for feed \(feedID): \(timestamp)")
        }
    }

    /// Load the last viewed timestamp for a feed
    func loadLastViewedTimestamp(forFeed feedID: String) -> Date? {
        let timestamps = loadAllLastViewedTimestamps()
        return timestamps[feedID]
    }

    /// Load all last viewed timestamps
    private func loadAllLastViewedTimestamps() -> [String: Date] {
        guard let data = UserDefaults.standard.data(forKey: "feedLastViewedTimestamps"),
              let timestamps = try? JSONDecoder().decode([String: Date].self, from: data) else {
            return [:]
        }
        return timestamps
    }

    /// Clear last viewed timestamp for a specific feed
    func clearLastViewedTimestamp(forFeed feedID: String) {
        var timestamps = loadAllLastViewedTimestamps()
        timestamps.removeValue(forKey: feedID)

        if let encoded = try? JSONEncoder().encode(timestamps) {
            UserDefaults.standard.set(encoded, forKey: "feedLastViewedTimestamps")
        }
    }

    /// Clear all last viewed timestamps
    func clearAllLastViewedTimestamps() {
        UserDefaults.standard.removeObject(forKey: "feedLastViewedTimestamps")
    }
}
