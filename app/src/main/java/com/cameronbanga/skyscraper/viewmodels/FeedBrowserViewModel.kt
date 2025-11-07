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
 * ViewModel for browsing and discovering custom feeds
 */
class FeedBrowserViewModel(application: Application) : AndroidViewModel(application) {

    private val client = ATProtoClient.getInstance()

    private val _feeds = MutableStateFlow<List<FeedGenerator>>(emptyList())
    val feeds: StateFlow<List<FeedGenerator>> = _feeds

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage

    private val _savedFeedURIs = MutableStateFlow<Set<String>>(emptySet())
    val savedFeedURIs: StateFlow<Set<String>> = _savedFeedURIs

    private val _isTogglingFeed = MutableStateFlow<String?>(null)
    val isTogglingFeed: StateFlow<String?> = _isTogglingFeed

    private var currentPreferences: List<Preference> = emptyList()

    init {
        loadFeeds()
    }

    /**
     * Load suggested feeds
     */
    fun loadFeeds() {
        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null

            try {
                // Load suggested feeds with maximum allowed limit (100)
                val response = client.getSuggestedFeeds(limit = 100)

                // Sort by popularity (likeCount)
                _feeds.value = response.feeds.sortedByDescending { it.likeCount ?: 0 }

                // Load current preferences to know which feeds are saved
                loadSavedFeeds()

                println("✅ Loaded ${_feeds.value.size} feeds for browsing")
            } catch (e: Exception) {
                _errorMessage.value = e.message ?: "Failed to load feeds"
                println("Failed to load feeds: $e")
            } finally {
                _isLoading.value = false
            }
        }
    }

    /**
     * Load saved feeds from preferences
     */
    private suspend fun loadSavedFeeds() {
        try {
            val preferencesResponse = client.getPreferences()
            currentPreferences = preferencesResponse.preferences

            // Extract saved feed URIs
            for (preference in preferencesResponse.preferences) {
                if (preference is Preference.SavedFeeds) {
                    _savedFeedURIs.value = preference.data.saved.toSet()
                    break
                }
            }
        } catch (e: Exception) {
            println("Failed to load saved feeds: $e")
        }
    }

    /**
     * Toggle save/unsave a feed
     */
    fun toggleSaveFeed(feedURI: String) {
        viewModelScope.launch {
            _isTogglingFeed.value = feedURI

            try {
                val newSaved = _savedFeedURIs.value.toMutableList()

                if (_savedFeedURIs.value.contains(feedURI)) {
                    // Remove from saved
                    newSaved.remove(feedURI)
                } else {
                    // Add to saved
                    newSaved.add(feedURI)
                }

                // Find existing SavedFeedsPref or create new one
                val updatedPreferences = currentPreferences.toMutableList()
                var foundSavedFeedsPref = false

                for (i in currentPreferences.indices) {
                    val preference = currentPreferences[i]
                    if (preference is Preference.SavedFeeds) {
                        // Update existing saved feeds preference
                        var newPinned = preference.data.pinned.toMutableList()
                        // If we're removing a feed, also remove it from pinned
                        if (!newSaved.contains(feedURI)) {
                            newPinned.remove(feedURI)
                        }

                        updatedPreferences[i] = Preference.SavedFeeds(
                            SavedFeedsPref(
                                pinned = newPinned,
                                saved = newSaved
                            )
                        )
                        foundSavedFeedsPref = true
                        break
                    }
                }

                // If no saved feeds pref exists, create one
                if (!foundSavedFeedsPref) {
                    updatedPreferences.add(
                        Preference.SavedFeeds(
                            SavedFeedsPref(
                                pinned = emptyList(),
                                saved = newSaved
                            )
                        )
                    )
                }

                // Save to server
                client.putPreferences(updatedPreferences)

                // Update local state
                currentPreferences = updatedPreferences
                _savedFeedURIs.value = newSaved.toSet()

                val action = _savedFeedURIs.value.contains(feedURI) ? "saved" : "removed"
                println("✅ Successfully $action feed")
            } catch (e: Exception) {
                println("Failed to toggle feed: $e")
                _errorMessage.value = "Failed to update feed. Please try again."
            } finally {
                _isTogglingFeed.value = null
            }
        }
    }
}
