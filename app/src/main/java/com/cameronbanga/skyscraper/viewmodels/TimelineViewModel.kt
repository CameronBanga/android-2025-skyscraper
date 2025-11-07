package com.cameronbanga.skyscraper.viewmodels

import android.app.Application
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.cameronbanga.skyscraper.models.FeedViewPost
import com.cameronbanga.skyscraper.models.PostViewer
import com.cameronbanga.skyscraper.services.ATProtoClient
import com.cameronbanga.skyscraper.services.AccountManager
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.Instant
import kotlin.math.abs

/**
 * Manages timeline feed state and operations
 * Handles pagination, refresh, background fetching, and post interactions
 */
class TimelineViewModel(application: Application) : AndroidViewModel(application) {

    companion object {
        private const val MINIMUM_FETCH_INTERVAL = 5000L // 5 seconds in milliseconds
        private const val POSTS_PER_PAGE = 50
        private const val MAX_BACKGROUND_FETCH_BATCHES = 10
        private const val MAX_PAGES_FOR_ANCHOR_SEARCH = 10
        private const val PREFETCH_LOOKAHEAD = 5
        private const val TOP_POSTS_CHECK = 3
        private const val MAX_CONSECUTIVE_FAILURES = 10
    }

    // Services
    private val client = ATProtoClient.getInstance()
    private val accountManager = AccountManager.getInstance(application)

    // State
    private val _state = MutableStateFlow(TimelineState())
    val state: StateFlow<TimelineState> = _state.asStateFlow()

    // Private tracking
    private var isBackgroundFetching = false
    private var lastFetchTime: Long? = null
    private val seenPostURIs = mutableSetOf<String>()
    private val newPostURIs = mutableSetOf<String>()
    private var consecutiveBackgroundFetchFailures = 0
    private var backgroundFetchJob: Job? = null

    // Account switch receiver
    private val accountSwitchReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == AccountManager.ACCOUNT_SWITCHED_ACTION) {
                handleAccountSwitch()
            }
        }
    }

    init {
        // Register account switch receiver
        val filter = IntentFilter(AccountManager.ACCOUNT_SWITCHED_ACTION)
        application.registerReceiver(accountSwitchReceiver, filter, Context.RECEIVER_EXPORTED)

        // Load timeline
        viewModelScope.launch {
            loadAvailableFeeds()
            loadTimeline()
            startBackgroundFetching()
        }
    }

    override fun onCleared() {
        super.onCleared()
        getApplication<Application>().unregisterReceiver(accountSwitchReceiver)
        stopBackgroundFetching()
    }

    // MARK: - Account Management

    private fun handleAccountSwitch() {
        stopBackgroundFetching()

        _state.update {
            it.copy(
                posts = emptyList(),
                cursor = null,
                pendingNewPosts = emptyList(),
                availableFeeds = emptyList(),
                selectedFeed = null
            )
        }

        clearNewPostsTracking()

        viewModelScope.launch {
            loadAvailableFeeds()
            loadTimeline()
            startBackgroundFetching()
        }
    }

    // MARK: - Background Fetching

    fun startBackgroundFetching() {
        // TODO: Implement with WorkManager for periodic background refresh
        // For now, using a simple coroutine with delay
        backgroundFetchJob?.cancel()
        backgroundFetchJob = viewModelScope.launch {
            while (true) {
                delay(60000L) // 60 seconds
                fetchNewPosts()
            }
        }
    }

    fun stopBackgroundFetching() {
        backgroundFetchJob?.cancel()
        backgroundFetchJob = null
    }

    private fun isUserAtTop(): Boolean {
        val visibleURI = _state.value.visiblePostURI
        val posts = _state.value.posts
        if (visibleURI == null || posts.isEmpty()) return true

        val topPostURIs = posts.take(TOP_POSTS_CHECK).map { it.post.uri }
        return topPostURIs.contains(visibleURI)
    }

    private suspend fun fetchNewPosts() {
        if (isBackgroundFetching || _state.value.isLoading || _state.value.isRefreshing || _state.value.posts.isEmpty()) {
            return
        }

        // Throttle: Don't fetch if we just fetched recently
        lastFetchTime?.let { lastFetch ->
            if (System.currentTimeMillis() - lastFetch < MINIMUM_FETCH_INTERVAL) {
                return
            }
        }

        lastFetchTime = System.currentTimeMillis()
        isBackgroundFetching = true

        try {
            val allNewPosts = mutableListOf<FeedViewPost>()
            var fetchCursor: String? = null
            val currentPostURIs = _state.value.posts.map { it.post.uri }.toSet()
            val pendingPostURIs = _state.value.pendingNewPosts.map { it.post.uri }.toSet()
            val allExistingURIs = currentPostURIs + pendingPostURIs
            var foundOverlap = false
            var batchCount = 0

            while (!foundOverlap && batchCount < MAX_BACKGROUND_FETCH_BATCHES) {
                batchCount++
                val response = client.getTimeline(limit = POSTS_PER_PAGE, cursor = fetchCursor)

                val newPostsInBatch = mutableListOf<FeedViewPost>()

                for (post in response.feed) {
                    if (allExistingURIs.contains(post.post.uri)) {
                        foundOverlap = true
                        break
                    } else {
                        newPostsInBatch.add(post)
                    }
                }

                allNewPosts.addAll(newPostsInBatch)
                fetchCursor = response.cursor

                if (fetchCursor == null || newPostsInBatch.isEmpty()) {
                    break
                }
            }

            if (allNewPosts.isNotEmpty()) {
                // Filter posts (moderation would go here)
                val filteredPosts = allNewPosts

                _state.update { currentState ->
                    val updatedPending = (currentState.pendingNewPosts + filteredPosts)
                        .distinctBy { it.post.uri }
                        .sortedByDescending { it.post.createdAt }

                    currentState.copy(
                        pendingNewPosts = updatedPending,
                        shouldAutoInsert = isUserAtTop()
                    )
                }

                // Update tracking
                newPostURIs.addAll(allNewPosts.map { it.post.uri })
                updateUnseenCount()

                // Reset failure counter on success
                consecutiveBackgroundFetchFailures = 0
                _state.update { it.copy(backgroundFetchError = null) }

                // TODO: Cache posts
            }
        } catch (e: Exception) {
            consecutiveBackgroundFetchFailures++
            if (consecutiveBackgroundFetchFailures >= MAX_CONSECUTIVE_FAILURES) {
                _state.update {
                    it.copy(backgroundFetchError = "Timeline updates paused - ${e.message}")
                }
            }
        } finally {
            isBackgroundFetching = false
        }
    }

    // MARK: - Post Tracking

    fun markPostAsSeen(postURI: String) {
        seenPostURIs.add(postURI)
        updateUnseenCount()

        // Prune tracking sets if all posts are seen
        if (newPostURIs.subtract(seenPostURIs).isEmpty()) {
            seenPostURIs.clear()
            newPostURIs.clear()
        }
    }

    fun prefetchImagesForUpcomingPosts(currentPostId: String) {
        val posts = _state.value.posts
        val currentIndex = posts.indexOfFirst { it.id == currentPostId }
        if (currentIndex >= 0) {
            val upcomingPosts = posts.drop(currentIndex + 1).take(PREFETCH_LOOKAHEAD)
            // TODO: Implement image prefetching with Coil
        }
    }

    private fun updateUnseenCount() {
        val unseenCount = (newPostURIs - seenPostURIs).size
        _state.update { it.copy(unseenPostsCount = unseenCount) }
    }

    private fun clearNewPostsTracking() {
        seenPostURIs.clear()
        newPostURIs.clear()
        _state.update { it.copy(unseenPostsCount = 0) }
    }

    fun insertPendingPosts() {
        val pending = _state.value.pendingNewPosts
        if (pending.isEmpty()) return

        // Step 1: Internal deduplication (within pending posts)
        val seenURIs = mutableSetOf<String>()
        val dedupedPending = pending.filter { post ->
            if (!seenURIs.contains(post.post.uri)) {
                seenURIs.add(post.post.uri)
                true
            } else {
                false
            }
        }

        // Step 2: Timeline deduplication (against current posts)
        val currentPostURIs = _state.value.posts.map { it.post.uri }.toSet()
        val uniqueNewPosts = dedupedPending.filter { !currentPostURIs.contains(it.post.uri) }

        // Step 3: Clean up tracking for dropped duplicates
        val dedupedURIs = dedupedPending.map { it.post.uri }.toSet()
        val insertedURIs = uniqueNewPosts.map { it.post.uri }.toSet()
        val droppedURIs = dedupedURIs - insertedURIs
        newPostURIs.removeAll(droppedURIs)

        // Insert at top and sort
        _state.update { currentState ->
            val allPosts = (uniqueNewPosts + currentState.posts)
                .sortedByDescending { it.post.createdAt }

            currentState.copy(
                posts = allPosts,
                pendingNewPosts = emptyList(),
                shouldAutoInsert = false
            )
        }

        clearNewPostsTracking()
    }

    // MARK: - Feed Management

    private suspend fun loadAvailableFeeds() {
        _state.update { it.copy(isLoadingFeeds = true) }

        try {
            val preferences = client.getPreferences()
            // TODO: Extract saved feeds from preferences and create FeedInfo list

            // For now, just use Following feed
            val feeds = listOf(FeedInfo.FOLLOWING)
            _state.update {
                it.copy(
                    availableFeeds = feeds,
                    selectedFeed = feeds.firstOrNull(),
                    isLoadingFeeds = false
                )
            }
        } catch (e: Exception) {
            _state.update {
                it.copy(
                    availableFeeds = listOf(FeedInfo.FOLLOWING),
                    selectedFeed = FeedInfo.FOLLOWING,
                    isLoadingFeeds = false
                )
            }
        }
    }

    fun switchToFeed(feed: FeedInfo) {
        if (_state.value.selectedFeed?.id == feed.id) return

        _state.update {
            it.copy(
                selectedFeed = feed,
                posts = emptyList(),
                cursor = null,
                pendingNewPosts = emptyList()
            )
        }

        clearNewPostsTracking()

        viewModelScope.launch {
            loadTimeline()
        }
    }

    // MARK: - Timeline Operations

    suspend fun loadTimeline() {
        _state.update { it.copy(isLoading = true, errorMessage = null) }

        try {
            // TODO: Load from cache first for instant display

            // Fetch from network
            val response = client.getTimeline(limit = POSTS_PER_PAGE)

            val sortedPosts = response.feed.sortedByDescending { it.post.createdAt }

            _state.update {
                it.copy(
                    posts = sortedPosts,
                    cursor = response.cursor,
                    isLoading = false
                )
            }

            // TODO: Cache posts
        } catch (e: Exception) {
            _state.update {
                it.copy(
                    isLoading = false,
                    errorMessage = e.message ?: "Failed to load timeline"
                )
            }
        }
    }

    suspend fun refresh() {
        _state.update { it.copy(isRefreshing = true) }

        try {
            // Insert pending posts first
            insertPendingPosts()

            // Fetch fresh timeline
            val response = client.getTimeline(limit = POSTS_PER_PAGE, cursor = null)

            val sortedPosts = response.feed.sortedByDescending { it.post.createdAt }

            _state.update {
                it.copy(
                    posts = sortedPosts,
                    cursor = response.cursor,
                    isRefreshing = false
                )
            }

            clearNewPostsTracking()

            // TODO: Update cache
        } catch (e: Exception) {
            _state.update {
                it.copy(
                    isRefreshing = false,
                    errorMessage = e.message
                )
            }
        }
    }

    suspend fun loadMore() {
        val cursor = _state.value.cursor ?: return
        if (_state.value.isLoading) return

        try {
            val response = client.getTimeline(limit = POSTS_PER_PAGE, cursor = cursor)

            _state.update { currentState ->
                val allPosts = (currentState.posts + response.feed)
                    .distinctBy { it.post.uri }
                    .sortedByDescending { it.post.createdAt }

                currentState.copy(
                    posts = allPosts,
                    cursor = response.cursor
                )
            }
        } catch (e: Exception) {
            // Silently fail for pagination
        }
    }

    fun saveScrollPosition(postURI: String) {
        val post = _state.value.posts.firstOrNull { it.post.uri == postURI }
        if (post != null) {
            _state.update {
                it.copy(
                    savedScrollAnchor = postURI,
                    savedAnchorTimestamp = post.post.createdAt.epochSecond
                )
            }
        }
    }

    // MARK: - Post Actions

    suspend fun toggleLike(feedPost: FeedViewPost) {
        val post = feedPost.post
        val isLiked = post.viewer?.like != null

        // Optimistic update
        val originalViewer = post.viewer
        val updatedViewer = if (isLiked) {
            post.viewer?.copy(like = null)
        } else {
            (post.viewer ?: PostViewer()).copy(like = "temp")
        }

        updatePostInState(post.uri) { feedViewPost ->
            feedViewPost.copy(
                post = feedViewPost.post.copy(
                    viewer = updatedViewer,
                    likeCount = (feedViewPost.post.likeCount ?: 0) + if (isLiked) -1 else 1
                )
            )
        }

        try {
            if (isLiked) {
                originalViewer?.like?.let { likeUri ->
                    client.unlikePost(likeUri)
                }
            } else {
                val likeUri = client.likePost(post.uri, post.cid)
                // Update with real URI
                updatePostInState(post.uri) { feedViewPost ->
                    feedViewPost.copy(
                        post = feedViewPost.post.copy(
                            viewer = feedViewPost.post.viewer?.copy(like = likeUri)
                        )
                    )
                }
            }
        } catch (e: Exception) {
            // Rollback on failure
            updatePostInState(post.uri) { feedViewPost ->
                feedViewPost.copy(
                    post = feedViewPost.post.copy(
                        viewer = originalViewer,
                        likeCount = (feedViewPost.post.likeCount ?: 0) + if (isLiked) 1 else -1
                    )
                )
            }
        }
    }

    suspend fun toggleRepost(feedPost: FeedViewPost) {
        val post = feedPost.post
        val isReposted = post.viewer?.repost != null

        // Optimistic update
        val originalViewer = post.viewer
        val updatedViewer = if (isReposted) {
            post.viewer?.copy(repost = null)
        } else {
            (post.viewer ?: PostViewer()).copy(repost = "temp")
        }

        updatePostInState(post.uri) { feedViewPost ->
            feedViewPost.copy(
                post = feedViewPost.post.copy(
                    viewer = updatedViewer,
                    repostCount = (feedViewPost.post.repostCount ?: 0) + if (isReposted) -1 else 1
                )
            )
        }

        try {
            if (isReposted) {
                originalViewer?.repost?.let { repostUri ->
                    client.unrepost(repostUri)
                }
            } else {
                val repostUri = client.repost(post.uri, post.cid)
                // Update with real URI
                updatePostInState(post.uri) { feedViewPost ->
                    feedViewPost.copy(
                        post = feedViewPost.post.copy(
                            viewer = feedViewPost.post.viewer?.copy(repost = repostUri)
                        )
                    )
                }
            }
        } catch (e: Exception) {
            // Rollback on failure
            updatePostInState(post.uri) { feedViewPost ->
                feedViewPost.copy(
                    post = feedViewPost.post.copy(
                        viewer = originalViewer,
                        repostCount = (feedViewPost.post.repostCount ?: 0) + if (isReposted) 1 else -1
                    )
                )
            }
        }
    }

    private fun updatePostInState(postURI: String, transform: (FeedViewPost) -> FeedViewPost) {
        _state.update { currentState ->
            currentState.copy(
                posts = currentState.posts.map { feedPost ->
                    if (feedPost.post.uri == postURI) {
                        transform(feedPost)
                    } else {
                        feedPost
                    }
                }
            )
        }
    }
}
