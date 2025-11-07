package com.cameronbanga.skyscraper.services

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import com.cameronbanga.skyscraper.models.ATProtoSession
import com.squareup.moshi.Moshi
import com.squareup.moshi.kotlin.reflect.KotlinJsonAdapterFactory

/**
 * Secure storage manager for credentials and sessions
 * Android equivalent of KeychainManager using EncryptedSharedPreferences
 */
class SecureStorageManager private constructor(context: Context) {

    companion object {
        @Volatile
        private var INSTANCE: SecureStorageManager? = null

        fun getInstance(context: Context): SecureStorageManager = INSTANCE ?: synchronized(this) {
            INSTANCE ?: SecureStorageManager(context.applicationContext).also { INSTANCE = it }
        }
    }

    private val masterKey = MasterKey.Builder(context)
        .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
        .build()

    private val encryptedPrefs: SharedPreferences = EncryptedSharedPreferences.create(
        context,
        "skyscraper_secure_prefs",
        masterKey,
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )

    private val moshi = Moshi.Builder()
        .addLast(KotlinJsonAdapterFactory())
        .build()

    private val sessionAdapter = moshi.adapter(ATProtoSession::class.java)

    // MARK: - Session Management

    fun saveSession(session: ATProtoSession, accountId: String) {
        val json = sessionAdapter.toJson(session)
        encryptedPrefs.edit()
            .putString("atproto_session_$accountId", json)
            .apply()
    }

    fun retrieveSession(accountId: String): ATProtoSession? {
        val json = encryptedPrefs.getString("atproto_session_$accountId", null) ?: return null
        return try {
            sessionAdapter.fromJson(json)
        } catch (e: Exception) {
            null
        }
    }

    fun deleteSession(accountId: String) {
        encryptedPrefs.edit()
            .remove("atproto_session_$accountId")
            .apply()
    }

    // MARK: - Credentials Management

    fun saveCredentials(identifier: String, password: String, accountId: String) {
        encryptedPrefs.edit()
            .putString("user_identifier_$accountId", identifier)
            .putString("user_password_$accountId", password)
            .apply()
    }

    fun retrieveCredentials(accountId: String): Pair<String, String>? {
        val identifier = encryptedPrefs.getString("user_identifier_$accountId", null) ?: return null
        val password = encryptedPrefs.getString("user_password_$accountId", null) ?: return null
        return Pair(identifier, password)
    }

    fun deleteCredentials(accountId: String) {
        encryptedPrefs.edit()
            .remove("user_identifier_$accountId")
            .remove("user_password_$accountId")
            .apply()
    }

    // MARK: - Generic Key-Value Storage

    fun save(key: String, value: String) {
        encryptedPrefs.edit()
            .putString(key, value)
            .apply()
    }

    fun retrieve(key: String): String? {
        return encryptedPrefs.getString(key, null)
    }

    fun delete(key: String) {
        encryptedPrefs.edit()
            .remove(key)
            .apply()
    }

    fun clearAll() {
        encryptedPrefs.edit().clear().apply()
    }
}
