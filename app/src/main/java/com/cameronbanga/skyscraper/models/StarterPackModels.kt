package com.cameronbanga.skyscraper.models

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass

/**
 * BlueSky Starter Pack model
 */
@JsonClass(generateAdapter = true)
data class StarterPack(
    val uri: String,
    val cid: String,
    val record: StarterPackRecord,
    val creator: Author,
    val listItemCount: Int? = null,
    val joinedWeekCount: Int? = null,
    val joinedAllTimeCount: Int? = null,
    val labels: List<Label>? = null,
    val indexedAt: String? = null
)

/**
 * StarterPack record data
 */
@JsonClass(generateAdapter = true)
data class StarterPackRecord(
    val name: String,
    val description: String? = null,
    val descriptionFacets: List<Facet>? = null,
    val list: String,
    val feeds: List<FeedItem>? = null,
    val createdAt: String
)

/**
 * Feed item reference
 */
@JsonClass(generateAdapter = true)
data class FeedItem(
    val uri: String
)

/**
 * Response containing list of starter packs
 */
@JsonClass(generateAdapter = true)
data class StarterPacksResponse(
    val starterPacks: List<StarterPack>,
    val cursor: String? = null
)

/**
 * List item view containing user information
 */
@JsonClass(generateAdapter = true)
data class ListItemView(
    val uri: String,
    val subject: Author
)

/**
 * Response for list items
 */
@JsonClass(generateAdapter = true)
data class ListItemsResponse(
    val cursor: String? = null,
    val items: List<ListItemView>
)

/**
 * List response (alias for ListItemsResponse)
 */
typealias ListResponse = ListItemsResponse
