package com.cameronbanga.skyscraper.data

import androidx.room.Entity
import androidx.room.PrimaryKey

/**
 * Room entity for caching timeline posts
 * Stores posts as JSON data for offline access and faster loading
 */
@Entity(tableName = "cached_posts")
data class CachedPost(
    @PrimaryKey
    val uri: String,
    val jsonData: ByteArray,
    val cachedAt: Long, // Timestamp in milliseconds
    val createdAt: Long, // Timestamp in milliseconds
    val sortOrder: Long,
    val feedId: String
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as CachedPost

        if (uri != other.uri) return false
        if (!jsonData.contentEquals(other.jsonData)) return false
        if (cachedAt != other.cachedAt) return false
        if (createdAt != other.createdAt) return false
        if (sortOrder != other.sortOrder) return false
        if (feedId != other.feedId) return false

        return true
    }

    override fun hashCode(): Int {
        var result = uri.hashCode()
        result = 31 * result + jsonData.contentHashCode()
        result = 31 * result + cachedAt.hashCode()
        result = 31 * result + createdAt.hashCode()
        result = 31 * result + sortOrder.hashCode()
        result = 31 * result + feedId.hashCode()
        return result
    }
}
