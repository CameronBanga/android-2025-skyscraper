package com.cameronbanga.skyscraper.utils

/**
 * Utilities for string processing
 */
object StringUtils {

    /**
     * Truncate text to a maximum length with ellipsis
     */
    fun truncate(text: String, maxLength: Int): String {
        return if (text.length > maxLength) {
            text.substring(0, maxLength - 3) + "..."
        } else {
            text
        }
    }

    /**
     * Format large numbers (e.g., 1000 -> 1K, 1000000 -> 1M)
     */
    fun formatNumber(num: Int): String {
        return when {
            num < 1000 -> num.toString()
            num < 1000000 -> String.format("%.1fK", num / 1000.0)
            else -> String.format("%.1fM", num / 1000000.0)
        }
    }

    /**
     * Extract mentions from text (@handle)
     */
    fun extractMentions(text: String): List<String> {
        val mentionPattern = Regex("""@([a-zA-Z0-9._-]+)""")
        return mentionPattern.findAll(text).map { it.groupValues[1] }.toList()
    }

    /**
     * Extract hashtags from text (#tag)
     */
    fun extractHashtags(text: String): List<String> {
        val hashtagPattern = Regex("""#([a-zA-Z0-9_]+)""")
        return hashtagPattern.findAll(text).map { it.groupValues[1] }.toList()
    }

    /**
     * Extract URLs from text
     */
    fun extractUrls(text: String): List<String> {
        val urlPattern = Regex("""https?://[^\s]+""")
        return urlPattern.findAll(text).map { it.value }.toList()
    }

    /**
     * Convert text to title case
     */
    fun toTitleCase(text: String): String {
        return text.split(" ").joinToString(" ") { word ->
            word.lowercase().replaceFirstChar { it.uppercase() }
        }
    }

    /**
     * Validate handle format
     */
    fun isValidHandle(handle: String): Boolean {
        val handlePattern = Regex("""^[a-zA-Z0-9][a-zA-Z0-9._-]*\.[a-zA-Z]{2,}$""")
        return handlePattern.matches(handle)
    }

    /**
     * Sanitize handle (remove @ if present)
     */
    fun sanitizeHandle(handle: String): String {
        return handle.removePrefix("@")
    }
}
