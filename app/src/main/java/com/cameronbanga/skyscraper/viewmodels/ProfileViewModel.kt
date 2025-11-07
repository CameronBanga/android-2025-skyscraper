package com.cameronbanga.skyscraper.viewmodels

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.cameronbanga.skyscraper.models.FeedViewPost
import com.cameronbanga.skyscraper.models.Profile
import com.cameronbanga.skyscraper.services.ATProtoClient
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * ViewModel for user profile display
 */
class ProfileViewModel(
    application: Application,
    val actor: String
) : AndroidViewModel(application) {

    private val client = ATProtoClient.getInstance()

    private val _profile = MutableStateFlow<Profile?>(null)
    val profile: StateFlow<Profile?> = _profile.asStateFlow()

    private val _posts = MutableStateFlow<List<FeedViewPost>>(emptyList())
    val posts: StateFlow<List<FeedViewPost>> = _posts.asStateFlow()

    private val _isLoading = MutableStateFlow(true)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _isLoadingContent = MutableStateFlow(false)
    val isLoadingContent: StateFlow<Boolean> = _isLoadingContent.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    private val _selectedTab = MutableStateFlow(ProfileTab.POSTS)
    val selectedTab: StateFlow<ProfileTab> = _selectedTab.asStateFlow()

    private var contentCursor: String? = null

    val isCurrentUser: Boolean
        get() = _profile.value?.did == client.session.value?.did

    init {
        loadProfile()
    }

    fun loadProfile() {
        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null

            try {
                val profile = client.getProfile(actor)
                _profile.value = profile
                loadContent()
            } catch (e: Exception) {
                _errorMessage.value = e.message ?: "Failed to load profile"
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun selectTab(tab: ProfileTab) {
        _selectedTab.value = tab
        loadContent()
    }

    fun loadContent() {
        viewModelScope.launch {
            _isLoadingContent.value = true
            _posts.value = emptyList()
            contentCursor = null

            try {
                when (_selectedTab.value) {
                    ProfileTab.POSTS -> {
                        val response = client.getAuthorFeed(actor, limit = 50)
                        _posts.value = response.feed
                        contentCursor = response.cursor
                    }
                    ProfileTab.REPLIES -> {
                        val response = client.getAuthorFeed(actor, limit = 50, filter = "posts_with_replies")
                        _posts.value = response.feed
                        contentCursor = response.cursor
                    }
                    ProfileTab.LIKES -> {
                        // Only available for current user
                        if (isCurrentUser) {
                            val response = client.getActorLikes(actor, limit = 50)
                            _posts.value = response.feed
                            contentCursor = response.cursor
                        }
                    }
                    ProfileTab.LISTS -> {
                        // TODO: Implement lists
                    }
                }
            } catch (e: Exception) {
                _errorMessage.value = e.message
            } finally {
                _isLoadingContent.value = false
            }
        }
    }

    fun loadMore() {
        if (contentCursor == null || _isLoadingContent.value) return

        viewModelScope.launch {
            try {
                when (_selectedTab.value) {
                    ProfileTab.POSTS -> {
                        val response = client.getAuthorFeed(actor, limit = 50, cursor = contentCursor)
                        _posts.value = _posts.value + response.feed
                        contentCursor = response.cursor
                    }
                    ProfileTab.REPLIES -> {
                        val response = client.getAuthorFeed(actor, limit = 50, filter = "posts_with_replies", cursor = contentCursor)
                        _posts.value = _posts.value + response.feed
                        contentCursor = response.cursor
                    }
                    ProfileTab.LIKES -> {
                        if (isCurrentUser) {
                            val response = client.getActorLikes(actor, limit = 50, cursor = contentCursor)
                            _posts.value = _posts.value + response.feed
                            contentCursor = response.cursor
                        }
                    }
                    ProfileTab.LISTS -> {
                        // TODO: Implement lists pagination
                    }
                }
            } catch (e: Exception) {
                // Ignore pagination errors
            }
        }
    }

    fun toggleFollow() {
        viewModelScope.launch {
            try {
                val currentProfile = _profile.value ?: return@launch

                if (currentProfile.viewer?.following != null) {
                    // Unfollow
                    currentProfile.viewer?.following?.let { followUri ->
                        client.deleteFollow(followUri)
                        _profile.value = currentProfile.copy(
                            viewer = currentProfile.viewer?.copy(following = null)
                        )
                    }
                } else {
                    // Follow
                    val followUri = client.follow(currentProfile.did)
                    _profile.value = currentProfile.copy(
                        viewer = currentProfile.viewer?.copy(following = followUri)
                            ?: ProfileViewerState(following = followUri)
                    )
                }
            } catch (e: Exception) {
                _errorMessage.value = "Failed to update follow status"
            }
        }
    }

    fun clearError() {
        _errorMessage.value = null
    }
}

enum class ProfileTab {
    POSTS,
    REPLIES,
    LIKES,
    LISTS
}

// Placeholder for ProfileViewerState
data class ProfileViewerState(
    val following: String? = null,
    val followedBy: String? = null,
    val muted: Boolean = false,
    val blocked: String? = null
)
