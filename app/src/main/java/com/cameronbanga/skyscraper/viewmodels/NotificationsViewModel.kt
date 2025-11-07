package com.cameronbanga.skyscraper.viewmodels

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.cameronbanga.skyscraper.models.Notification
import com.cameronbanga.skyscraper.services.ATProtoClient
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * ViewModel for notifications and activity
 */
class NotificationsViewModel(application: Application) : AndroidViewModel(application) {

    private val client = ATProtoClient.getInstance()

    private val _notifications = MutableStateFlow<List<Notification>>(emptyList())
    val notifications: StateFlow<List<Notification>> = _notifications.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    private var cursor: String? = null

    fun loadNotifications() {
        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null

            try {
                val response = client.getNotifications(limit = 50)
                _notifications.value = response.notifications
                cursor = response.cursor
            } catch (e: Exception) {
                _errorMessage.value = e.message ?: "Failed to load notifications"
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun refresh() {
        cursor = null
        loadNotifications()
    }

    fun loadMore() {
        if (cursor == null || _isLoading.value) return

        viewModelScope.launch {
            try {
                val response = client.getNotifications(limit = 50, cursor = cursor)
                _notifications.value = _notifications.value + response.notifications
                cursor = response.cursor
            } catch (e: Exception) {
                // Ignore pagination errors
            }
        }
    }

    fun markAllAsRead() {
        viewModelScope.launch {
            try {
                client.markNotificationsAsRead()
                // Update local state
                _notifications.value = _notifications.value.map { it.copy(isRead = true) }
            } catch (e: Exception) {
                _errorMessage.value = "Failed to mark as read"
            }
        }
    }

    fun clearError() {
        _errorMessage.value = null
    }
}
