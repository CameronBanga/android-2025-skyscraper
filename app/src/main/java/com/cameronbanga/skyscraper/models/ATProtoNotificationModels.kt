package com.cameronbanga.skyscraper.models

import com.squareup.moshi.JsonClass

// MARK: - Notification Models

@JsonClass(generateAdapter = true)
data class NotificationsResponse(
    val notifications: List<Notification>,
    val cursor: String? = null
)

@JsonClass(generateAdapter = true)
data class Notification(
    val uri: String,
    val cid: String? = null,
    val author: Author,  // Who triggered notification
    val reason: String,  // Notification type (like, repost, follow, reply, etc.)
    val reasonSubject: String? = null,  // URI of affected post
    val record: PostRecord? = null,  // Only for reply notifications
    val isRead: Boolean,
    val indexedAt: String,
    val labels: List<Label>? = null
) {
    val id: String get() = uri
}
