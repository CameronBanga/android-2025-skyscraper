package com.cameronbanga.skyscraper.viewmodels

import com.cameronbanga.skyscraper.models.FeedViewPost

/**
 * Centralized state for TimelineViewModel
 * Encapsulates all published state for the timeline
 */
data class TimelineState(
    val posts: List<FeedViewPost> = emptyList(),
    val isLoading: Boolean = false,
    val isRefreshing: Boolean = false,
    val errorMessage: String? = null,
    val cursor: String? = null,
    val scrollToPostURI: String? = null,
    val unseenPostsCount: Int = 0,
    val availableFeeds: List<FeedInfo> = emptyList(),
    val selectedFeed: FeedInfo? = null,
    val isLoadingFeeds: Boolean = false,
    val pendingNewPosts: List<FeedViewPost> = emptyList(),
    val visiblePostURI: String? = null,
    val backgroundFetchError: String? = null,
    val shouldAutoInsert: Boolean = false,
    val savedScrollAnchor: String? = null,  // Post URI to restore scroll position to
    val savedAnchorTimestamp: Long? = null  // Timestamp of the anchor post for fallback
)

/**
 * Feed information model
 */
data class FeedInfo(
    val id: String,
    val uri: String? = null,  // null for "Following" feed
    val displayName: String,
    val description: String? = null,
    val avatar: String? = null
) {
    companion object {
        val FOLLOWING = FeedInfo(
            id = "following",
            uri = null,
            displayName = "Following",
            description = "Posts from people you follow",
            avatar = null
        )
    }
}
