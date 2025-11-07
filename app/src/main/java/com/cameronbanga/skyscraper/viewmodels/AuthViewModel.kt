package com.cameronbanga.skyscraper.viewmodels

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.cameronbanga.skyscraper.services.ATProtoClient
import com.cameronbanga.skyscraper.services.AccountManager
import com.cameronbanga.skyscraper.services.SecureStorageManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * ViewModel for authentication state
 * Manages login, logout, and session checking
 */
class AuthViewModel(application: Application) : AndroidViewModel(application) {

    private val client = ATProtoClient.getInstance()
    private val accountManager = AccountManager.getInstance(application)
    private val secureStorage = SecureStorageManager.getInstance(application)

    private val _isCheckingSession = MutableStateFlow(true)
    val isCheckingSession: StateFlow<Boolean> = _isCheckingSession.asStateFlow()

    private val _isAuthenticated = MutableStateFlow(false)
    val isAuthenticated: StateFlow<Boolean> = _isAuthenticated.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    init {
        checkSession()
    }

    private fun checkSession() {
        viewModelScope.launch {
            _isCheckingSession.value = true

            try {
                // Check for saved session
                val activeAccountId = accountManager.activeAccountId.value
                if (activeAccountId != null) {
                    val session = secureStorage.retrieveSession(activeAccountId)
                    if (session != null) {
                        // TODO: Set session in ATProtoClient
                        _isAuthenticated.value = true
                    } else {
                        _isAuthenticated.value = false
                    }
                } else {
                    _isAuthenticated.value = false
                }
            } catch (e: Exception) {
                _isAuthenticated.value = false
                _errorMessage.value = e.message
            } finally {
                _isCheckingSession.value = false
            }
        }
    }

    fun login(identifier: String, password: String, customPDSURL: String? = null) {
        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null

            try {
                // Perform login
                client.login(identifier, password, customPDSURL)

                // Get the session from client
                val session = client.session.value
                if (session != null) {
                    // Save session to secure storage
                    secureStorage.saveSession(session, session.did)

                    // Save credentials for future use
                    secureStorage.saveCredentials(identifier, password, session.did)

                    // Add account to account manager
                    // We'll need to fetch profile to get display name and avatar
                    try {
                        val profile = client.getProfile(session.did)
                        accountManager.addAccount(
                            did = session.did,
                            handle = session.handle,
                            displayName = profile.displayName,
                            avatar = profile.avatar
                        )
                    } catch (e: Exception) {
                        // Add account without profile info
                        accountManager.addAccount(
                            did = session.did,
                            handle = session.handle,
                            displayName = null,
                            avatar = null
                        )
                    }

                    _isAuthenticated.value = true
                }
            } catch (e: Exception) {
                _errorMessage.value = e.message ?: "Login failed"
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun logout() {
        viewModelScope.launch {
            try {
                client.logout()

                // Clear session from secure storage
                accountManager.activeAccountId.value?.let { accountId ->
                    secureStorage.deleteSession(accountId)
                }

                _isAuthenticated.value = false
            } catch (e: Exception) {
                _errorMessage.value = e.message
            }
        }
    }

    fun clearError() {
        _errorMessage.value = null
    }
}
