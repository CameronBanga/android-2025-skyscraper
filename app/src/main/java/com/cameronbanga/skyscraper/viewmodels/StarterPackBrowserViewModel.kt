package com.cameronbanga.skyscraper.viewmodels

import android.app.Application
import android.content.Context
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.cameronbanga.skyscraper.models.StarterPack
import com.cameronbanga.skyscraper.services.ATProtoClient
import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass
import com.squareup.moshi.Moshi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

/**
 * ViewModel for browsing curated starter packs
 */
class StarterPackBrowserViewModel(application: Application) : AndroidViewModel(application) {

    private val client = ATProtoClient.getInstance()
    private val context: Context = application.applicationContext

    private val _starterPacks = MutableStateFlow<List<StarterPack>>(emptyList())
    val starterPacks: StateFlow<List<StarterPack>> = _starterPacks

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage

    init {
        loadStarterPacks()
    }

    /**
     * Load starter packs from configuration and API
     */
    fun loadStarterPacks() {
        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null

            try {
                // Load config from JSON file
                val configItems = loadStarterPackConfig()
                if (configItems == null) {
                    _starterPacks.value = emptyList()
                    _isLoading.value = false
                    return@launch
                }

                // Resolve handles to DIDs and build URIs
                val uris = mutableListOf<String>()
                for (item in configItems) {
                    if (item.handle.startsWith("did:")) {
                        // Already a DID
                        uris.add("at://${item.handle}/app.bsky.graph.starterpack/${item.rkey}")
                    } else {
                        // Need to resolve handle to DID
                        try {
                            val profile = client.getProfile(actor = item.handle)
                            uris.add("at://${profile.did}/app.bsky.graph.starterpack/${item.rkey}")
                        } catch (e: Exception) {
                            println("Failed to resolve handle ${item.handle}: $e")
                            // Skip this starter pack
                        }
                    }
                }

                if (uris.isEmpty()) {
                    _starterPacks.value = emptyList()
                    _isLoading.value = false
                    return@launch
                }

                // Fetch starter packs from API
                val response = client.getStarterPacks(uris)

                // Preserve the original order from the API response
                _starterPacks.value = response.starterPacks

                println("✅ Loaded ${_starterPacks.value.size} starter packs")
            } catch (e: Exception) {
                _errorMessage.value = e.message ?: "Failed to load starter packs"
                println("Failed to load starter packs: $e")
            } finally {
                _isLoading.value = false
            }
        }
    }

    /**
     * Load starter pack configuration from JSON file
     */
    private fun loadStarterPackConfig(): List<StarterPackConfigItem>? {
        return try {
            val json = context.assets.open("StarterPacks.json").bufferedReader().use {
                it.readText()
            }

            val moshi = Moshi.Builder().build()
            val adapter = moshi.adapter(StarterPacksConfig::class.java)
            val config = adapter.fromJson(json)

            config?.starterPacks
        } catch (e: Exception) {
            println("Failed to load StarterPacks.json: $e")
            // Return empty list if config file doesn't exist
            emptyList()
        }
    }
}

/**
 * Configuration model for starter packs
 */
@JsonClass(generateAdapter = true)
data class StarterPacksConfig(
    val starterPacks: List<StarterPackConfigItem>
)

/**
 * Individual starter pack configuration item
 */
@JsonClass(generateAdapter = true)
data class StarterPackConfigItem(
    val name: String,
    val handle: String, // Can be either a handle (e.g., "user.bsky.social") or DID (e.g., "did:plc:...")
    val rkey: String,   // The record key from the URL
    val category: String
)
