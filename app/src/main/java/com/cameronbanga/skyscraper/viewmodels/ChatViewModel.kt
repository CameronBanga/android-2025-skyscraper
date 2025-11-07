package com.cameronbanga.skyscraper.viewmodels

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.cameronbanga.skyscraper.models.ConvoView
import com.cameronbanga.skyscraper.models.MessageInput
import com.cameronbanga.skyscraper.models.MessageUnion
import com.cameronbanga.skyscraper.models.MessageView
import com.cameronbanga.skyscraper.services.ATProtoClient
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

/**
 * ViewModel for managing an individual chat conversation
 * Handles loading messages, sending messages, and polling for updates
 */
class ChatViewModel(
    application: Application,
    val conversation: ConvoView
) : AndroidViewModel(application) {

    private val client = ATProtoClient.getInstance()

    private val _messages = MutableStateFlow<List<MessageUnion>>(emptyList())
    val messages: StateFlow<List<MessageUnion>> = _messages.asStateFlow()

    private val _messageText = MutableStateFlow("")
    val messageText: StateFlow<String> = _messageText.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _isSending = MutableStateFlow(false)
    val isSending: StateFlow<Boolean> = _isSending.asStateFlow()

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
                    pollForNewMessages()
                }
            }
        }
    }

    fun stopPolling() {
        pollingJob?.cancel()
        pollingJob = null
    }

    fun loadMessages() {
        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null

            try {
                val response = client.getMessages(conversation.id, limit = 50)
                _messages.value = response.messages.reversed() // Reverse to show oldest first
                cursor = response.cursor

                // Mark as read
                try {
                    client.updateRead(conversation.id)
                } catch (e: Exception) {
                    // Ignore read update errors
                }
            } catch (e: Exception) {
                _errorMessage.value = e.message ?: "Failed to load messages"
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun updateMessageText(text: String) {
        _messageText.value = text
    }

    fun sendMessage() {
        val textToSend = _messageText.value.trim()
        if (textToSend.isEmpty()) {
            return
        }

        viewModelScope.launch {
            _messageText.value = "" // Clear immediately for better UX
            _isSending.value = true

            try {
                val messageInput = MessageInput(text = textToSend)
                val response = client.sendMessage(conversation.id, messageInput)

                // Add the new message to the list
                val newMessage = MessageView(
                    id = response.id,
                    rev = response.rev,
                    text = response.text,
                    facets = response.facets,
                    embed = response.embed,
                    sender = response.sender,
                    sentAt = response.sentAt
                )
                _messages.value = _messages.value + MessageUnion.MessageView(newMessage)
            } catch (e: Exception) {
                // Restore the text so user can try again
                _messageText.value = textToSend
                _errorMessage.value = "Failed to send message. Please try again."
            } finally {
                _isSending.value = false
            }
        }
    }

    fun loadMoreMessages() {
        val currentCursor = cursor
        if (currentCursor == null || _isLoading.value) {
            return
        }

        viewModelScope.launch {
            try {
                val response = client.getMessages(conversation.id, limit = 50, cursor = currentCursor)
                _messages.value = response.messages.reversed() + _messages.value
                cursor = response.cursor
            } catch (e: Exception) {
                // Ignore pagination errors
            }
        }
    }

    private suspend fun pollForNewMessages() {
        if (_isLoading.value || _isSending.value) {
            return
        }

        try {
            // Get the latest messages without cursor to fetch newest ones
            val response = client.getMessages(conversation.id, limit = 50)
            val newMessages = response.messages.reversed()

            // Find messages we don't have yet
            val existingIds = _messages.value.map { it.id }.toSet()
            val messagesToAdd = newMessages.filter { !existingIds.contains(it.id) }

            if (messagesToAdd.isNotEmpty()) {
                _messages.value = _messages.value + messagesToAdd

                // Mark as read
                try {
                    client.updateRead(conversation.id)
                } catch (e: Exception) {
                    // Ignore read update errors
                }
            }
        } catch (e: Exception) {
            // Ignore polling errors
        }
    }

    fun clearError() {
        _errorMessage.value = null
    }
}
