package com.cameronbanga.skyscraper.services

import android.content.Context
import android.content.SharedPreferences
import com.cameronbanga.skyscraper.data.CachedPost
import com.cameronbanga.skyscraper.data.SkyscraperDatabase
import com.cameronbanga.skyscraper.models.FeedViewPost
import com.squareup.moshi.Moshi
import com.squareup.moshi.Types
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.util.concurrent.TimeUnit

/**
 * Service for caching and retrieving timeline posts using Room
 * Provides offline access and faster loading of timeline data
 */
class PostCacheService private constructor(private val context: Context) {

    companion object {
        @Volatile
        private var INSTANCE: PostCacheService? = null

        fun getInstance(context: Context): PostCacheService = INSTANCE ?: synchronized(this) {
            INSTANCE ?: PostCacheService(context.applicationContext).also { INSTANCE = it }
        }

        val shared get() = INSTANCE
            ?: throw IllegalStateException("PostCacheService not initialized")

        private const val SCROLL_POSITIONS_KEY = "feedScrollPositions"
        private const val CACHE_MAX_AGE_DAYS = 10
    }

    private val database = SkyscraperDatabase.getInstance(context)
    private val cachedPostDao = database.cachedPostDao()
    private val moshi = Moshi.Builder().build()
    private val feedViewPostAdapter = moshi.adapter(FeedViewPost::class.java)
    private val prefs: SharedPreferences = context.getSharedPreferences(
        "post_cache_prefs",
        Context.MODE_PRIVATE
    )

    /**
     * Cache posts for a specific feed
     */
    suspend fun cachePosts(posts: List<FeedViewPost>, feedId: String) = withContext(Dispatchers.IO) {
        try {
            val cachedPosts = posts.mapIndexed { index, feedPost ->
                val jsonData = feedViewPostAdapter.toJson(feedPost).toByteArray()
                CachedPost(
                    uri = feedPost.post.uri,
                    jsonData = jsonData,
                    cachedAt = System.currentTimeMillis(),
                    createdAt = parseCreatedAt(feedPost.post.record.createdAt),
                    sortOrder = index.toLong(),
                    feedId = feedId
                )
            }

            cachedPostDao.insertPosts(cachedPosts)
        } catch (e: Exception) {
            // Log error but don't crash
        }
    }

    /**
     * Load cached posts for a specific feed
     */
    suspend fun loadCachedPosts(feedId: String): List<FeedViewPost> = withContext(Dispatchers.IO) {
        try {
            val cachedPosts = cachedPostDao.getPostsForFeed(feedId)
            cachedPosts.mapNotNull { cached ->
                try {
                    val jsonString = String(cached.jsonData)
                    feedViewPostAdapter.fromJson(jsonString)
                } catch (e: Exception) {
                    null
                }
            }
        } catch (e: Exception) {
            emptyList()
        }
    }

    /**
     * Load all cached posts across all feeds
     */
    suspend fun loadAllCachedPosts(): List<FeedViewPost> = withContext(Dispatchers.IO) {
        try {
            // Since we don't have a "get all" query, we'd need to add it
            // For now, return empty list as this is mainly for cache size calculation
            emptyList()
        } catch (e: Exception) {
            emptyList()
        }
    }

    /**
     * Clear all cached posts
     */
    suspend fun clearCache() = withContext(Dispatchers.IO) {
        try {
            cachedPostDao.clearAll()
        } catch (e: Exception) {
            // Log error but don't crash
        }
    }

    /**
     * Clean up old posts (older than 10 days)
     */
    suspend fun cleanupOldPosts() = withContext(Dispatchers.IO) {
        try {
            val cutoffTime = System.currentTimeMillis() - TimeUnit.DAYS.toMillis(CACHE_MAX_AGE_DAYS.toLong())
            cachedPostDao.deleteOldPosts(cutoffTime)
        } catch (e: Exception) {
            // Log error but don't crash
        }
    }

    /**
     * Save scroll position for a specific feed
     */
    fun saveScrollPosition(postURI: String, forFeed feedId: String) {
        try {
            val positions = loadAllScrollPositions().toMutableMap()
            positions[feedId] = postURI

            val json = moshi.adapter<Map<String, String>>(
                Types.newParameterizedType(Map::class.java, String::class.java, String::class.java)
            ).toJson(positions)

            prefs.edit()
                .putString(SCROLL_POSITIONS_KEY, json)
                .apply()
        } catch (e: Exception) {
            // Log error but don't crash
        }
    }

    /**
     * Load scroll position for a specific feed
     */
    fun loadScrollPosition(forFeed feedId: String): String? {
        return loadAllScrollPositions()[feedId]
    }

    /**
     * Load all scroll positions
     */
    private fun loadAllScrollPositions(): Map<String, String> {
        return try {
            val json = prefs.getString(SCROLL_POSITIONS_KEY, null) ?: return emptyMap()
            moshi.adapter<Map<String, String>>(
                Types.newParameterizedType(Map::class.java, String::class.java, String::class.java)
            ).fromJson(json) ?: emptyMap()
        } catch (e: Exception) {
            emptyMap()
        }
    }

    /**
     * Parse createdAt string to timestamp
     */
    private fun parseCreatedAt(createdAt: String): Long {
        return try {
            // ISO 8601 format parsing
            val formatter = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", java.util.Locale.getDefault())
            formatter.parse(createdAt)?.time ?: System.currentTimeMillis()
        } catch (e: Exception) {
            System.currentTimeMillis()
        }
    }
}
