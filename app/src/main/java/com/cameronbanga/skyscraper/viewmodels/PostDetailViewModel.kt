package com.cameronbanga.skyscraper.viewmodels

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.cameronbanga.skyscraper.models.*
import com.cameronbanga.skyscraper.services.ATProtoClient
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

/**
 * ViewModel for viewing a post thread with parent chain and replies
 */
class PostDetailViewModel(
    application: Application,
    private val postUri: String
) : AndroidViewModel(application) {

    private val client = ATProtoClient.getInstance()

    private val _thread = MutableStateFlow<ThreadViewPost?>(null)
    val thread: StateFlow<ThreadViewPost?> = _thread

    private val _isLoading = MutableStateFlow(true)
    val isLoading: StateFlow<Boolean> = _isLoading

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage

    // Track which replies are expanded for pagination
    private val _expandedReplies = MutableStateFlow<Set<String>>(emptySet())
    val expandedReplies: StateFlow<Set<String>> = _expandedReplies

    // Track which nested threads are loading
    private val _loadingNestedThreads = MutableStateFlow<Set<String>>(emptySet())
    val loadingNestedThreads: StateFlow<Set<String>> = _loadingNestedThreads

    init {
        loadThread()
    }

    /**
     * Load the thread for the post
     */
    fun loadThread() {
        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null

            try {
                val response = client.getPostThread(postUri)
                _thread.value = response.thread
            } catch (e: Exception) {
                _errorMessage.value = e.message ?: "Failed to load thread"
            } finally {
                _isLoading.value = false
            }
        }
    }

    /**
     * Get the parent chain (list of posts from root to current post)
     */
    fun getParentChain(thread: ThreadViewPost): List<ThreadViewPost> {
        val chain = mutableListOf<ThreadViewPost>()
        var current: ThreadViewPost? = thread.parent

        while (current != null) {
            chain.add(0, current)
            current = current.parent
        }

        return chain
    }

    /**
     * Toggle expansion of replies for a given post
     * Used for client-side pagination when there are many replies
     */
    fun toggleRepliesExpansion(postUri: String) {
        val currentExpanded = _expandedReplies.value.toMutableSet()
        if (currentExpanded.contains(postUri)) {
            currentExpanded.remove(postUri)
        } else {
            currentExpanded.add(postUri)
        }
        _expandedReplies.value = currentExpanded
    }

    /**
     * Load nested replies for a post
     * Used for server-side pagination when replies have more replies
     */
    fun loadNestedReplies(postUri: String) {
        viewModelScope.launch {
            val currentLoading = _loadingNestedThreads.value.toMutableSet()
            currentLoading.add(postUri)
            _loadingNestedThreads.value = currentLoading

            try {
                val response = client.getPostThread(postUri)

                // Update the thread with nested replies
                _thread.value?.let { currentThread ->
                    _thread.value = updateThreadWithNested(currentThread, postUri, response.thread)
                }
            } catch (e: Exception) {
                // Silently fail or show a toast
            } finally {
                val newLoading = _loadingNestedThreads.value.toMutableSet()
                newLoading.remove(postUri)
                _loadingNestedThreads.value = newLoading
            }
        }
    }

    /**
     * Recursively update the thread tree with nested replies
     */
    private fun updateThreadWithNested(
        current: ThreadViewPost,
        targetUri: String,
        nestedThread: ThreadViewPost
    ): ThreadViewPost {
        if (current.post.uri == targetUri) {
            return nestedThread
        }

        val updatedReplies = current.replies?.map { reply ->
            updateThreadWithNested(reply, targetUri, nestedThread)
        }

        return current.copy(replies = updatedReplies)
    }

    /**
     * Like a post in the thread
     */
    fun likePost(post: Post) {
        viewModelScope.launch {
            try {
                val updatedPost = client.toggleLike(post)
                _thread.value?.let { currentThread ->
                    _thread.value = updatePostInThread(currentThread, updatedPost)
                }
            } catch (e: Exception) {
                // Silently fail or show error
            }
        }
    }

    /**
     * Repost a post in the thread
     */
    fun repostPost(post: Post) {
        viewModelScope.launch {
            try {
                val updatedPost = client.toggleRepost(post)
                _thread.value?.let { currentThread ->
                    _thread.value = updatePostInThread(currentThread, updatedPost)
                }
            } catch (e: Exception) {
                // Silently fail or show error
            }
        }
    }

    /**
     * Recursively update a post in the thread tree
     */
    private fun updatePostInThread(
        current: ThreadViewPost,
        updatedPost: Post
    ): ThreadViewPost {
        if (current.post.uri == updatedPost.uri) {
            return current.copy(post = updatedPost)
        }

        // Check parent
        val updatedParent = current.parent?.let { parent ->
            updatePostInThread(parent, updatedPost)
        }

        // Check replies
        val updatedReplies = current.replies?.map { reply ->
            updatePostInThread(reply, updatedPost)
        }

        return current.copy(
            parent = updatedParent,
            replies = updatedReplies
        )
    }

    /**
     * Get visible replies for a post (considering client-side pagination)
     */
    fun getVisibleReplies(postUri: String, replies: List<ThreadViewPost>?): List<ThreadViewPost> {
        if (replies == null) return emptyList()

        val isExpanded = _expandedReplies.value.contains(postUri)

        return if (isExpanded || replies.size <= 3) {
            replies
        } else {
            replies.take(3)
        }
    }

    /**
     * Check if "Show more replies" button should be shown
     */
    fun shouldShowMoreReplies(postUri: String, replies: List<ThreadViewPost>?): Boolean {
        if (replies == null || replies.size <= 3) return false
        return !_expandedReplies.value.contains(postUri)
    }
}
