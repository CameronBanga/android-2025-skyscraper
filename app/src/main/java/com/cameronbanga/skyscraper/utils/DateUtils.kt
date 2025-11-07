package com.cameronbanga.skyscraper.utils

import java.text.SimpleDateFormat
import java.util.*
import kotlin.math.abs

/**
 * Utilities for date and time formatting
 */
object DateUtils {

    /**
     * Format a date string as a relative time (e.g., "2h ago", "3d ago")
     */
    fun formatRelativeTime(dateString: String): String {
        return try {
            val sdf = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault())
            val date = sdf.parse(dateString) ?: return ""
            val now = Date()
            val diffMs = now.time - date.time
            val diffSeconds = abs(diffMs / 1000)

            when {
                diffSeconds < 60 -> "now"
                diffSeconds < 3600 -> "${diffSeconds / 60}m"
                diffSeconds < 86400 -> "${diffSeconds / 3600}h"
                diffSeconds < 604800 -> "${diffSeconds / 86400}d"
                diffSeconds < 2592000 -> "${diffSeconds / 604800}w"
                else -> {
                    // Format as date for older posts
                    SimpleDateFormat("MMM d", Locale.getDefault()).format(date)
                }
            }
        } catch (e: Exception) {
            ""
        }
    }

    /**
     * Format a date string as a full timestamp
     */
    fun formatFullTimestamp(dateString: String): String {
        return try {
            val sdf = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault())
            val date = sdf.parse(dateString) ?: return ""
            SimpleDateFormat("MMM d, yyyy 'at' h:mm a", Locale.getDefault()).format(date)
        } catch (e: Exception) {
            dateString
        }
    }

    /**
     * Parse ISO 8601 date string to timestamp
     */
    fun parseToTimestamp(dateString: String): Long {
        return try {
            val sdf = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault())
            sdf.parse(dateString)?.time ?: System.currentTimeMillis()
        } catch (e: Exception) {
            System.currentTimeMillis()
        }
    }
}
