package com.cameronbanga.skyscraper.models

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass

// MARK: - Preferences Models

@JsonClass(generateAdapter = true)
data class PreferencesResponse(
    val preferences: List<PreferenceJson>
)

/**
 * JSON representation for preferences decoding
 */
@JsonClass(generateAdapter = true)
data class PreferenceJson(
    @field:Json(name = "\$type") val type: String,
    // SavedFeedsPref fields
    val pinned: List<String>? = null,
    val saved: List<String>? = null,
    val items: List<SavedFeedItem>? = null,
    // AdultContentPref fields
    val enabled: Boolean? = null,
    // ContentLabelPref fields
    val label: String? = null,
    val visibility: String? = null
) {
    fun toPreference(): Preference? = when {
        type.contains("savedFeedsPref") -> {
            // Handle both V1 and V2 formats
            val pinnedFeeds = pinned ?: items?.filter { it.pinned == true }?.mapNotNull { it.value } ?: emptyList()
            val savedFeeds = saved ?: items?.mapNotNull { it.value } ?: emptyList()
            Preference.SavedFeeds(SavedFeedsPref(pinnedFeeds, savedFeeds))
        }
        type.contains("adultContentPref") -> {
            enabled?.let { Preference.AdultContent(AdultContentPref(it)) }
        }
        type.contains("contentLabelPref") -> {
            if (label != null && visibility != null) {
                Preference.ContentLabel(ContentLabelPref(label, visibility))
            } else null
        }
        else -> Preference.Other(type)
    }
}

/**
 * Sealed interface for preferences
 */
sealed interface Preference {
    data class SavedFeeds(val pref: SavedFeedsPref) : Preference
    data class AdultContent(val pref: AdultContentPref) : Preference
    data class ContentLabel(val pref: ContentLabelPref) : Preference
    data class Other(val type: String) : Preference
}

@JsonClass(generateAdapter = true)
data class SavedFeedsPref(
    val pinned: List<String>,
    val saved: List<String>
) {
    fun toJson(): PreferenceJson = PreferenceJson(
        type = "app.bsky.actor.defs#savedFeedsPref",
        pinned = pinned,
        saved = saved
    )
}

@JsonClass(generateAdapter = true)
data class SavedFeedItem(
    val id: String? = null,
    val type: String,
    val value: String? = null,
    val pinned: Boolean? = null
)

@JsonClass(generateAdapter = true)
data class AdultContentPref(
    val enabled: Boolean
) {
    fun toJson(): PreferenceJson = PreferenceJson(
        type = "app.bsky.actor.defs#adultContentPref",
        enabled = enabled
    )
}

@JsonClass(generateAdapter = true)
data class ContentLabelPref(
    val label: String,
    val visibility: String  // "hide", "warn", or "show"
) {
    fun toJson(): PreferenceJson = PreferenceJson(
        type = "app.bsky.actor.defs#contentLabelPref",
        label = label,
        visibility = visibility
    )
}
