package com.cameronbanga.skyscraper.viewmodels

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.cameronbanga.skyscraper.models.ConvoView
import com.cameronbanga.skyscraper.services.ATProtoClient
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

/**
 * ViewModel for managing chat conversations list
 * Handles loading, pagination, and polling for updates
 */
class ChatListViewModel(application: Application) : AndroidViewModel(application) {

    private val client = ATProtoClient.getInstance()

    private val _conversations = MutableStateFlow<List<ConvoView>>(emptyList())
    val conversations: StateFlow<List<ConvoView>> = _conversations.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    private var cursor: String? = null
    private var pollingJob: Job? = null

    override fun onCleared() {
        super.onCleared()
        stopPolling()
    }

    fun startPolling() {
        // Cancel any existing polling task
        pollingJob?.cancel()

        pollingJob = viewModelScope.launch {
            while (isActive) {
                // Wait 2.5 seconds
                delay(2500)

                if (isActive) {
                    pollForUpdates()
                }
            }
        }
    }

    fun stopPolling() {
        pollingJob?.cancel()
        pollingJob = null
    }

    fun loadConversations() {
        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null

            try {
                val response = client.listConvos(limit = 50)
                _conversations.value = response.convos
                cursor = response.cursor
            } catch (e: Exception) {
                _errorMessage.value = e.message ?: "Failed to load conversations"
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun refreshConversations() {
        cursor = null
        loadConversations()
    }

    fun loadMoreIfNeeded(conversation: ConvoView) {
        val lastConvo = _conversations.value.lastOrNull()
        if (lastConvo?.id == conversation.id && cursor != null && !_isLoading.value) {
            viewModelScope.launch {
                try {
                    val response = client.listConvos(limit = 50, cursor = cursor)
                    _conversations.value = _conversations.value + response.convos
                    cursor = response.cursor
                } catch (e: Exception) {
                    // Ignore pagination errors
                }
            }
        }
    }

    private suspend fun pollForUpdates() {
        if (_isLoading.value) {
            return
        }

        try {
            // Fetch the latest conversations
            val response = client.listConvos(limit = 50)

            // Check if anything actually changed
            val hasChanges = response.convos != _conversations.value

            // Replace with fresh data from the API
            _conversations.value = response.convos
            cursor = response.cursor
        } catch (e: Exception) {
            // Ignore polling errors
        }
    }

    fun clearError() {
        _errorMessage.value = null
    }
}
