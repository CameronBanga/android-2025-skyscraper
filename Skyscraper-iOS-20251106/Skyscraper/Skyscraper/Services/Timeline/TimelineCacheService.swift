//
//  TimelineCacheService.swift
//  Skyscraper
//
//  Protocol for caching timeline posts
//

import Foundation

/// Service responsible for caching and retrieving timeline posts
protocol TimelineCacheService {
    /// Cache posts for a specific feed
    func cachePosts(_ posts: [FeedViewPost], feedId: String)

    /// Load cached posts for a specific feed
    func loadCachedPosts(feedId: String) -> [FeedViewPost]

    /// Clean up old cached posts
    func cleanupOldPosts()

    /// Prefetch images for posts
    func prefetchImages(for posts: [FeedViewPost])

    /// Prefetch images and wait for completion
    func prefetchImagesAndWait(for posts: [FeedViewPost]) async

    /// Save scroll position for a specific feed
    func saveScrollPosition(postURI: String, forFeed feedId: String)

    /// Load scroll position for a specific feed
    func loadScrollPosition(forFeed feedId: String) -> String?

    /// Save last viewed timestamp for a feed
    func saveLastViewedTimestamp(_ timestamp: Date, forFeed feedId: String)

    /// Load last viewed timestamp for a feed
    func loadLastViewedTimestamp(forFeed feedId: String) -> Date?

    /// Clear scroll position for a specific feed
    func clearScrollPosition(forFeed feedId: String)
}

/// Default implementation using PostCacheService and ImagePrefetchService
@MainActor
class DefaultTimelineCacheService: TimelineCacheService {
    private let postCache: PostCacheService
    private let imagePrefetcher: ImagePrefetchService

    init(
        postCache: PostCacheService? = nil,
        imagePrefetcher: ImagePrefetchService? = nil
    ) {
        self.postCache = postCache ?? PostCacheService.shared
        self.imagePrefetcher = imagePrefetcher ?? ImagePrefetchService.shared
    }

    func cachePosts(_ posts: [FeedViewPost], feedId: String) {
        postCache.cachePosts(posts, feedId: feedId)
    }

    func loadCachedPosts(feedId: String) -> [FeedViewPost] {
        postCache.loadCachedPosts(feedId: feedId)
    }

    func cleanupOldPosts() {
        postCache.cleanupOldPosts()
    }

    func prefetchImages(for posts: [FeedViewPost]) {
        imagePrefetcher.prefetchImages(for: posts)
    }

    func prefetchImagesAndWait(for posts: [FeedViewPost]) async {
        await imagePrefetcher.prefetchImagesAndWait(for: posts)
    }

    func saveScrollPosition(postURI: String, forFeed feedId: String) {
        postCache.saveScrollPosition(postURI: postURI, forFeed: feedId)
    }

    func loadScrollPosition(forFeed feedId: String) -> String? {
        postCache.loadScrollPosition(forFeed: feedId)
    }

    func saveLastViewedTimestamp(_ timestamp: Date, forFeed feedId: String) {
        postCache.saveLastViewedTimestamp(timestamp, forFeed: feedId)
    }

    func loadLastViewedTimestamp(forFeed feedId: String) -> Date? {
        postCache.loadLastViewedTimestamp(forFeed: feedId)
    }

    func clearScrollPosition(forFeed feedId: String) {
        postCache.clearScrollPosition(forFeed: feedId)
    }
}
