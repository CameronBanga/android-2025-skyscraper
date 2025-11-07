package com.cameronbanga.skyscraper.viewmodels

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.cameronbanga.skyscraper.models.Profile
import com.cameronbanga.skyscraper.services.ATProtoClient
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * ViewModel for user search
 * Handles searching for users with debouncing
 */
class SearchViewModel(application: Application) : AndroidViewModel(application) {

    private val client = ATProtoClient.getInstance()

    private val _users = MutableStateFlow<List<Profile>>(emptyList())
    val users: StateFlow<List<Profile>> = _users.asStateFlow()

    private val _isSearching = MutableStateFlow(false)
    val isSearching: StateFlow<Boolean> = _isSearching.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    private var searchJob: Job? = null

    fun search(query: String) {
        // Cancel previous search
        searchJob?.cancel()

        val trimmedQuery = query.trim()
        if (trimmedQuery.isEmpty()) {
            _users.value = emptyList()
            return
        }

        searchJob = viewModelScope.launch {
            try {
                // Debounce search
                delay(300)

                _isSearching.value = true
                _errorMessage.value = null

                val results = client.searchUsers(trimmedQuery)
                _users.value = results
            } catch (e: Exception) {
                _errorMessage.value = e.message
            } finally {
                _isSearching.value = false
            }
        }
    }

    fun clearResults() {
        _users.value = emptyList()
        _errorMessage.value = null
    }
}
