package com.cameronbanga.skyscraper.services

import android.content.Context
import android.content.SharedPreferences
import com.cameronbanga.skyscraper.models.PostDraft
import com.squareup.moshi.Moshi
import com.squareup.moshi.Types
import com.squareup.moshi.kotlin.reflect.KotlinJsonAdapterFactory
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.UUID

/**
 * Manager for post drafts with local persistence
 */
class DraftManager private constructor(context: Context) {

    companion object {
        @Volatile
        private var INSTANCE: DraftManager? = null

        fun getInstance(context: Context): DraftManager = INSTANCE ?: synchronized(this) {
            INSTANCE ?: DraftManager(context.applicationContext).also { INSTANCE = it }
        }

        val shared: DraftManager get() = INSTANCE
            ?: throw IllegalStateException("DraftManager not initialized")

        private const val PREFS_NAME = "com.skyscraper.postDrafts"
        private const val KEY_DRAFTS = "drafts"
        private const val MAX_DRAFTS = 50
    }

    private val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val moshi = Moshi.Builder()
        .addLast(KotlinJsonAdapterFactory())
        .build()

    private val _drafts = MutableStateFlow<List<PostDraft>>(emptyList())
    val drafts: StateFlow<List<PostDraft>> = _drafts.asStateFlow()

    init {
        loadDrafts()
    }

    /**
     * Save a draft (creates new or updates existing)
     */
    fun saveDraft(draft: PostDraft) {
        val currentDrafts = _drafts.value.toMutableList()

        // Update existing draft or add new one
        val existingIndex = currentDrafts.indexOfFirst { it.id == draft.id }
        if (existingIndex >= 0) {
            val updatedDraft = draft.copy(updatedAt = System.currentTimeMillis())
            currentDrafts[existingIndex] = updatedDraft
        } else {
            currentDrafts.add(0, draft) // Add to beginning
        }

        // Keep only the most recent drafts
        val limitedDrafts = if (currentDrafts.size > MAX_DRAFTS) {
            currentDrafts.take(MAX_DRAFTS)
        } else {
            currentDrafts
        }

        _drafts.value = limitedDrafts
        persistDrafts()
    }

    /**
     * Delete a draft
     */
    fun deleteDraft(draft: PostDraft) {
        val currentDrafts = _drafts.value.toMutableList()
        currentDrafts.removeAll { it.id == draft.id }
        _drafts.value = currentDrafts
        persistDrafts()
    }

    /**
     * Get a draft by ID
     */
    fun getDraft(id: String): PostDraft? {
        return _drafts.value.firstOrNull { it.id == id }
    }

    /**
     * Load drafts from SharedPreferences
     */
    private fun loadDrafts() {
        val json = prefs.getString(KEY_DRAFTS, null)
        if (json != null) {
            try {
                val type = Types.newParameterizedType(List::class.java, PostDraft::class.java)
                val adapter = moshi.adapter<List<PostDraft>>(type)
                val loaded = adapter.fromJson(json)
                _drafts.value = loaded ?: emptyList()
            } catch (e: Exception) {
                println("Failed to load drafts: $e")
                _drafts.value = emptyList()
            }
        } else {
            _drafts.value = emptyList()
        }
    }

    /**
     * Persist drafts to SharedPreferences
     */
    private fun persistDrafts() {
        try {
            val type = Types.newParameterizedType(List::class.java, PostDraft::class.java)
            val adapter = moshi.adapter<List<PostDraft>>(type)
            val json = adapter.toJson(_drafts.value)
            prefs.edit().putString(KEY_DRAFTS, json).apply()
        } catch (e: Exception) {
            println("Failed to persist drafts: $e")
        }
    }
}
