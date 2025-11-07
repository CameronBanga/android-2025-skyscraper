package com.cameronbanga.skyscraper.services

import android.content.Context
import android.content.SharedPreferences
import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass
import com.squareup.moshi.Moshi
import com.squareup.moshi.Types
import com.squareup.moshi.kotlin.reflect.KotlinJsonAdapterFactory
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

@JsonClass(generateAdapter = true)
data class StoredAccount(
    val id: String,  // DID
    val handle: String,
    val displayName: String? = null,
    val avatar: String? = null
)

/**
 * Multi-account management for BlueSky
 */
class AccountManager private constructor(private val context: Context) {

    companion object {
        @Volatile
        private var INSTANCE: AccountManager? = null

        fun getInstance(context: Context): AccountManager = INSTANCE ?: synchronized(this) {
            INSTANCE ?: AccountManager(context.applicationContext).also { INSTANCE = it }
        }

        val ACCOUNT_SWITCHED_ACTION = "com.cameronbanga.skyscraper.ACCOUNT_SWITCHED"
    }

    private val prefs: SharedPreferences = context.getSharedPreferences(
        "skyscraper_accounts",
        Context.MODE_PRIVATE
    )

    private val secureStorage = SecureStorageManager.getInstance(context)

    private val moshi = Moshi.Builder()
        .addLast(KotlinJsonAdapterFactory())
        .build()

    private val accountListAdapter = moshi.adapter<List<StoredAccount>>(
        Types.newParameterizedType(List::class.java, StoredAccount::class.java)
    )

    private val _accounts = MutableStateFlow<List<StoredAccount>>(emptyList())
    val accounts: StateFlow<List<StoredAccount>> = _accounts.asStateFlow()

    private val _activeAccountId = MutableStateFlow<String?>(null)
    val activeAccountId: StateFlow<String?> = _activeAccountId.asStateFlow()

    val activeAccount: StoredAccount?
        get() = _activeAccountId.value?.let { id ->
            _accounts.value.firstOrNull { it.id == id }
        }

    init {
        loadAccounts()
    }

    private fun loadAccounts() {
        val json = prefs.getString("accounts", null)
        _accounts.value = if (json != null) {
            try {
                accountListAdapter.fromJson(json) ?: emptyList()
            } catch (e: Exception) {
                emptyList()
            }
        } else {
            emptyList()
        }

        _activeAccountId.value = prefs.getString("active_account_id", null)

        // If no active account but we have accounts, set the first as active
        if (_activeAccountId.value == null && _accounts.value.isNotEmpty()) {
            _activeAccountId.value = _accounts.value.first().id
            saveActiveAccount()
        }
    }

    fun addAccount(did: String, handle: String, displayName: String?, avatar: String?) {
        val existingIndex = _accounts.value.indexOfFirst { it.id == did }

        val updatedAccounts = if (existingIndex >= 0) {
            // Update existing account
            _accounts.value.toMutableList().apply {
                this[existingIndex] = StoredAccount(did, handle, displayName, avatar)
            }
        } else {
            // Add new account
            _accounts.value + StoredAccount(did, handle, displayName, avatar)
        }

        _accounts.value = updatedAccounts
        saveAccounts()

        // Set as active if it's the first account
        if (updatedAccounts.size == 1) {
            _activeAccountId.value = did
            saveActiveAccount()
        }
    }

    suspend fun switchAccount(accountId: String) {
        if (_accounts.value.none { it.id == accountId }) return

        _activeAccountId.value = accountId
        saveActiveAccount()

        // Load session from secure storage and set in ATProtoClient
        val session = secureStorage.retrieveSession(accountId)
        if (session != null) {
            ATProtoClient.getInstance().apply {
                // Update session - note: In real implementation, ATProtoClient would need
                // a method to update its session from the manager
            }
        }

        // Broadcast account switch
        val intent = android.content.Intent(ACCOUNT_SWITCHED_ACTION)
        context.sendBroadcast(intent)
    }

    fun removeAccount(did: String) {
        _accounts.value = _accounts.value.filter { it.id != did }
        saveAccounts()

        // If we removed the active account, switch to another or set to null
        if (_activeAccountId.value == did) {
            _activeAccountId.value = _accounts.value.firstOrNull()?.id
            saveActiveAccount()
        }

        // Clear credentials for this account
        secureStorage.deleteCredentials(did)
        secureStorage.deleteSession(did)
    }

    private fun saveAccounts() {
        val json = accountListAdapter.toJson(_accounts.value)
        prefs.edit()
            .putString("accounts", json)
            .apply()
    }

    private fun saveActiveAccount() {
        val id = _activeAccountId.value
        if (id != null) {
            prefs.edit()
                .putString("active_account_id", id)
                .apply()
        } else {
            prefs.edit()
                .remove("active_account_id")
                .apply()
        }
    }
}
