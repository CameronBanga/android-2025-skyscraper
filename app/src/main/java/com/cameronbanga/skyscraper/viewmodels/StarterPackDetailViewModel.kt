package com.cameronbanga.skyscraper.viewmodels

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.cameronbanga.skyscraper.models.Author
import com.cameronbanga.skyscraper.models.ListItemView
import com.cameronbanga.skyscraper.models.ProfileViewer
import com.cameronbanga.skyscraper.services.ATProtoClient
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

/**
 * ViewModel for viewing individual starter pack details
 */
class StarterPackDetailViewModel(application: Application) : AndroidViewModel(application) {

    private val client = ATProtoClient.getInstance()

    private val _users = MutableStateFlow<List<ListItemView>>(emptyList())
    val users: StateFlow<List<ListItemView>> = _users

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage

    private val _togglingFollowDID = MutableStateFlow<String?>(null)
    val togglingFollowDID: StateFlow<String?> = _togglingFollowDID

    private val _isFollowingAll = MutableStateFlow(false)
    val isFollowingAll: StateFlow<Boolean> = _isFollowingAll

    /**
     * Load users from starter pack list
     */
    fun loadUsers(listURI: String) {
        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null

            try {
                val response = client.getList(list = listURI, limit = 100)
                _users.value = response.items

                println("✅ Loaded ${_users.value.size} users from starter pack")
            } catch (e: Exception) {
                _errorMessage.value = e.message ?: "Failed to load users"
                println("Failed to load users: $e")
            } finally {
                _isLoading.value = false
            }
        }
    }

    /**
     * Toggle follow/unfollow for a user
     */
    fun toggleFollow(user: Author) {
        viewModelScope.launch {
            _togglingFollowDID.value = user.did

            try {
                if (user.viewer?.following != null) {
                    // Unfollow
                    client.unfollowUser(followUri = user.viewer.following)

                    // Update local state
                    val updatedUsers = _users.value.map { item ->
                        if (item.subject.did == user.did) {
                            val updatedUser = item.subject.copy(
                                viewer = item.subject.viewer?.copy(following = null)
                            )
                            item.copy(subject = updatedUser)
                        } else {
                            item
                        }
                    }
                    _users.value = updatedUsers

                    println("📊 Analytics: Logged user_interaction (unfollow from starter pack)")
                } else {
                    // Follow
                    val followURI = client.followUser(did = user.did)

                    // Update local state
                    val updatedUsers = _users.value.map { item ->
                        if (item.subject.did == user.did) {
                            val updatedViewer = item.subject.viewer?.copy(following = followURI)
                                ?: ProfileViewer(
                                    muted = false,
                                    blockedBy = false,
                                    following = followURI,
                                    followedBy = null
                                )
                            val updatedUser = item.subject.copy(viewer = updatedViewer)
                            item.copy(subject = updatedUser)
                        } else {
                            item
                        }
                    }
                    _users.value = updatedUsers

                    println("📊 Analytics: Logged user_interaction (follow from starter pack)")
                }
            } catch (e: Exception) {
                println("Failed to toggle follow: $e")
            } finally {
                _togglingFollowDID.value = null
            }
        }
    }

    /**
     * Follow all users in the starter pack
     */
    fun followAll() {
        viewModelScope.launch {
            _isFollowingAll.value = true

            // Get all users who aren't already followed
            val usersToFollow = _users.value.filter { it.subject.viewer?.following == null }

            println("📍 Following ${usersToFollow.size} users from starter pack")

            for (item in usersToFollow) {
                try {
                    // Follow the user
                    val followURI = client.followUser(did = item.subject.did)

                    // Update local state
                    val updatedUsers = _users.value.map { currentItem ->
                        if (currentItem.subject.did == item.subject.did) {
                            val updatedViewer = currentItem.subject.viewer?.copy(following = followURI)
                                ?: ProfileViewer(
                                    muted = false,
                                    blockedBy = false,
                                    following = followURI,
                                    followedBy = null
                                )
                            val updatedUser = currentItem.subject.copy(viewer = updatedViewer)
                            currentItem.copy(subject = updatedUser)
                        } else {
                            currentItem
                        }
                    }
                    _users.value = updatedUsers

                    println("✅ Followed @${item.subject.handle}")
                } catch (e: Exception) {
                    println("Failed to follow @${item.subject.handle}: $e")
                }

                // Small delay to avoid rate limiting
                delay(100) // 0.1 seconds
            }

            println("📊 Analytics: Logged follow_all (${usersToFollow.size} users)")

            _isFollowingAll.value = false
        }
    }
}
