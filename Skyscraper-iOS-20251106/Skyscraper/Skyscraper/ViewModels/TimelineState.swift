//
//  TimelineState.swift
//  Skyscraper
//
//  Centralized state for TimelineViewModel
//

import Foundation

/// Encapsulates all published state for the timeline
struct TimelineState {
    var posts: [FeedViewPost] = []
    var isLoading = false
    var isRefreshing = false
    var errorMessage: String?
    var cursor: String?
    var scrollToPostURI: String?
    var unseenPostsCount: Int = 0
    var availableFeeds: [FeedInfo] = []
    var selectedFeed: FeedInfo?
    var isLoadingFeeds = false
    var pendingNewPosts: [FeedViewPost] = []
    var visiblePostURI: String?
    var backgroundFetchError: String?
    var shouldAutoInsert = false
    var savedScrollAnchor: String? // Post URI to restore scroll position to
    var savedAnchorTimestamp: Date? // Timestamp of the anchor post for fallback
}
