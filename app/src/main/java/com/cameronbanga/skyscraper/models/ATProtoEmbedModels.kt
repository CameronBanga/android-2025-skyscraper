package com.cameronbanga.skyscraper.models

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass

// MARK: - Embed Models

/**
 * Post-level embed (from API response)
 * Handles polymorphic embed types based on $type field
 */
@JsonClass(generateAdapter = true)
data class PostEmbed(
    val images: List<ImageView>? = null,
    val external: ExternalView? = null,
    val record: EmbeddedPostRecord? = null,
    val video: VideoView? = null,
    val media: MediaEmbed? = null,
    @field:Json(name = "\$type") val type: String? = null,
    // Video view properties (when embed IS the video)
    val cid: String? = null,
    val playlist: String? = null,
    val thumbnail: String? = null,
    val alt: String? = null,
    val aspectRatio: AspectRatio? = null
)

/**
 * For handling recordWithMedia type embeds
 */
@JsonClass(generateAdapter = true)
data class MediaEmbed(
    val images: List<ImageView>? = null,
    val video: VideoView? = null,
    val external: ExternalView? = null,
    @field:Json(name = "\$type") val type: String? = null,
    // Video view properties
    val cid: String? = null,
    val playlist: String? = null,
    val thumbnail: String? = null,
    val alt: String? = null,
    val aspectRatio: AspectRatio? = null
)

/**
 * Quoted/embedded posts
 */
@JsonClass(generateAdapter = true)
data class EmbeddedPostRecord(
    @field:Json(name = "\$type") val type: String? = null,
    val uri: String? = null,
    val cid: String? = null,
    val author: Author? = null,
    val value: PostRecord? = null,
    val labels: List<Label>? = null,
    val likeCount: Int? = null,
    val replyCount: Int? = null,
    val repostCount: Int? = null,
    val quoteCount: Int? = null,
    val indexedAt: String? = null,
    val embeds: List<PostEmbed>? = null
)

// Simple embed types for creating posts

sealed interface Embed {
    data class Images(val images: ImagesEmbed) : Embed
    data class External(val external: ExternalEmbed) : Embed
    data class Record(val record: RecordEmbed) : Embed
}

@JsonClass(generateAdapter = true)
data class ImagesEmbed(
    val images: List<ImageView>
)

@JsonClass(generateAdapter = true)
data class ImageView(
    val thumb: String,
    val fullsize: String,
    val alt: String
) {
    val id: String get() = fullsize
}

@JsonClass(generateAdapter = true)
data class VideoView(
    val cid: String? = null,
    val playlist: String,  // m3u8 URL for HLS streaming
    val thumbnail: String? = null,
    val alt: String? = null,
    val aspectRatio: AspectRatio? = null
) {
    val id: String get() = playlist
}

@JsonClass(generateAdapter = true)
data class AspectRatio(
    val width: Int,
    val height: Int
)

@JsonClass(generateAdapter = true)
data class ExternalEmbed(
    val external: ExternalView
)

@JsonClass(generateAdapter = true)
data class ExternalView(
    val uri: String,
    val title: String,
    val description: String,
    val thumb: String? = null
)

@JsonClass(generateAdapter = true)
data class RecordEmbed(
    val record: EmbeddedRecord
)

@JsonClass(generateAdapter = true)
data class EmbeddedRecord(
    val uri: String,
    val cid: String
)

// MARK: - Facets (Rich Text Features)

@JsonClass(generateAdapter = true)
data class Facet(
    val index: ByteSlice,
    val features: List<FeatureJson>
)

@JsonClass(generateAdapter = true)
data class ByteSlice(
    val byteStart: Int,
    val byteEnd: Int
)

/**
 * Rich text feature types
 * JSON representation for encoding/decoding
 */
@JsonClass(generateAdapter = true)
data class FeatureJson(
    @field:Json(name = "\$type") val type: String,
    val uri: String? = null,
    val did: String? = null,
    val tag: String? = null
) {
    fun toFeature(): Feature = when (type) {
        "app.bsky.richtext.facet#link" -> Feature.Link(uri ?: "")
        "app.bsky.richtext.facet#mention" -> Feature.Mention(did ?: "")
        "app.bsky.richtext.facet#tag" -> Feature.Tag(tag ?: "")
        else -> Feature.Link("") // Fallback
    }

    companion object {
        fun fromFeature(feature: Feature): FeatureJson = when (feature) {
            is Feature.Link -> FeatureJson(
                type = "app.bsky.richtext.facet#link",
                uri = feature.url
            )
            is Feature.Mention -> FeatureJson(
                type = "app.bsky.richtext.facet#mention",
                did = feature.did
            )
            is Feature.Tag -> FeatureJson(
                type = "app.bsky.richtext.facet#tag",
                tag = feature.tag
            )
        }
    }
}

/**
 * Sealed interface for rich text features
 */
sealed interface Feature {
    data class Link(val url: String) : Feature
    data class Mention(val did: String) : Feature
    data class Tag(val tag: String) : Feature
}
