package com.cameronbanga.skyscraper.models

import com.squareup.moshi.JsonClass
import java.time.Instant
import java.util.UUID

@JsonClass(generateAdapter = true)
data class PostDraft(
    val id: String = UUID.randomUUID().toString(),
    var text: String,
    var imageData: List<ByteArray> = emptyList(),
    var imageAltTexts: List<String> = emptyList(),
    val createdAt: Long = System.currentTimeMillis(),
    var updatedAt: Long = System.currentTimeMillis(),
    var languageId: String,
    var moderationSettings: PostModerationSettings
) {
    val preview: String
        get() = if (text.isEmpty()) {
            "Empty draft"
        } else {
            if (text.length > 100) text.take(100) + "..." else text
        }

    val relativeTime: String
        get() {
            val now = System.currentTimeMillis()
            val interval = (now - updatedAt) / 1000  // Convert to seconds
            val minutes = interval / 60
            val hours = interval / 3600
            val days = interval / 86400

            return when {
                days > 0 -> "${days}d ago"
                hours > 0 -> "${hours}h ago"
                minutes > 0 -> "${minutes}m ago"
                else -> "Just now"
            }
        }
}
