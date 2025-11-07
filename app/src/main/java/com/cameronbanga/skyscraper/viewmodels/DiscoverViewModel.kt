package com.cameronbanga.skyscraper.viewmodels

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.cameronbanga.skyscraper.models.Profile
import com.cameronbanga.skyscraper.services.ATProtoClient
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * ViewModel for discovering suggested users and trending topics
 */
class DiscoverViewModel(application: Application) : AndroidViewModel(application) {

    private val client = ATProtoClient.getInstance()

    private val _suggestedUsers = MutableStateFlow<List<Profile>>(emptyList())
    val suggestedUsers: StateFlow<List<Profile>> = _suggestedUsers.asStateFlow()

    private val _trendingTopics = MutableStateFlow<List<TrendingTopic>>(emptyList())
    val trendingTopics: StateFlow<List<TrendingTopic>> = _trendingTopics.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _isLoadingTopics = MutableStateFlow(false)
    val isLoadingTopics: StateFlow<Boolean> = _isLoadingTopics.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    // List of interesting accounts to suggest
    private val suggestedHandles = listOf(
        "cameronbanga.com",
        "giantbomb.bsky.social",
        "jeffgerstmann.com",
        "kenwhite.bsky.social",
        "frailgesture.bsky.social",
        "bsky.app",
        "atproto.com"
    )

    fun loadSuggestions() {
        if (_isLoading.value) return

        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null

            // Load trending topics and suggested users in parallel
            val topicsDeferred = async { loadTrendingTopics() }
            val usersDeferred = async { loadUsers() }

            topicsDeferred.await()
            usersDeferred.await()

            _isLoading.value = false
        }
    }

    private suspend fun loadTrendingTopics() {
        _isLoadingTopics.value = true

        try {
            val response = client.getTrendingTopics(limit = 10)
            _trendingTopics.value = response.topics
        } catch (e: Exception) {
            // Continue even if topics fail to load
        }

        _isLoadingTopics.value = false
    }

    private suspend fun loadUsers() {
        val profiles = mutableListOf<Profile>()

        for (handle in suggestedHandles) {
            // Basic validation
            if (handle.isEmpty() || !handle.contains(".")) {
                continue
            }

            try {
                val profile = client.getProfile(handle)
                profiles.add(profile)
            } catch (e: Exception) {
                // Continue loading other profiles
            }
        }

        _suggestedUsers.value = profiles
    }

    fun clearError() {
        _errorMessage.value = null
    }
}

/**
 * Temporary placeholder for TrendingTopic
 * TODO: Move to models package and implement properly
 */
data class TrendingTopic(
    val tag: String,
    val postCount: Int
)
