package com.cameronbanga.skyscraper.models

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass
import java.time.Instant
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeFormatterBuilder
import java.time.temporal.ChronoField

// MARK: - Authentication Models

@JsonClass(generateAdapter = true)
data class ATProtoSession(
    val did: String,
    val handle: String,
    val email: String? = null,
    val accessJwt: String,
    val refreshJwt: String,
    val pdsURL: String? = null
)

@JsonClass(generateAdapter = true)
data class CreateSessionRequest(
    val identifier: String,
    val password: String
)

@JsonClass(generateAdapter = true)
data class CreateSessionResponse(
    val did: String,
    val handle: String,
    val email: String? = null,
    val accessJwt: String,
    val refreshJwt: String
)

// MARK: - Post Models

@JsonClass(generateAdapter = true)
data class Post(
    val uri: String,
    val cid: String,
    val author: Author,
    val record: PostRecord,
    val replyCount: Int? = null,
    var repostCount: Int? = null,
    var likeCount: Int? = null,
    val quoteCount: Int? = null,
    val bookmarkCount: Int? = null,
    val indexedAt: String? = null,
    var viewer: PostViewer? = null,
    val embed: PostEmbed? = null,
    @field:Json(name = "reply") val replyRef: ReplyRef? = null,
    val labels: List<Label>? = null
) {
    val id: String get() = uri

    val createdAt: Instant get() {
        return try {
            // Try parsing with fractional seconds first
            Instant.from(DateTimeFormatter.ISO_INSTANT.parse(record.createdAt))
        } catch (e: Exception) {
            try {
                // Fallback to parsing without fractional seconds
                Instant.parse(record.createdAt)
            } catch (e: Exception) {
                Instant.now()
            }
        }
    }
}

@JsonClass(generateAdapter = true)
data class PostRecord(
    val text: String,
    val createdAt: String,
    val facets: List<Facet>? = null,
    val langs: List<String>? = null,
    val tags: List<String>? = null
)

@JsonClass(generateAdapter = true)
data class PostViewer(
    var like: String? = null,
    var repost: String? = null,
    val bookmarked: Boolean? = null,
    val threadMuted: Boolean? = null,
    val replyDisabled: Boolean? = null,
    val embeddingDisabled: Boolean? = null
)

@JsonClass(generateAdapter = true)
data class StrongRef(
    val uri: String,
    val cid: String
)

// MARK: - Author/Profile Models

@JsonClass(generateAdapter = true)
data class Author(
    val did: String,
    val handle: String? = null,  // Can be null for deleted/suspended accounts
    val displayName: String? = null,
    val description: String? = null,
    val avatar: String? = null,
    val associated: AuthorAssociated? = null,
    var viewer: ProfileViewer? = null,
    val labels: List<Label>? = null,
    val createdAt: String? = null
) {
    val id: String get() = did

    val safeHandle: String get() = handle ?: "deleted.account"

    val shortHandle: String get() {
        val fullHandle = safeHandle
        val firstPeriod = fullHandle.indexOf('.')
        return if (firstPeriod > 0) {
            fullHandle.substring(0, firstPeriod)
        } else {
            fullHandle
        }
    }

    fun canReceiveMessagesFrom(currentUserFollowsThem: Boolean): Boolean {
        val allowIncoming = associated?.chat?.allowIncoming ?: return currentUserFollowsThem

        return when (allowIncoming) {
            "all" -> true
            "following" -> currentUserFollowsThem
            "none" -> false
            else -> currentUserFollowsThem // Default to "following" for unknown values
        }
    }
}

@JsonClass(generateAdapter = true)
data class AuthorAssociated(
    val activitySubscription: ActivitySubscription? = null,
    val chat: ChatDeclaration? = null
)

@JsonClass(generateAdapter = true)
data class ChatDeclaration(
    val allowIncoming: String // "all", "following", or "none"
)

@JsonClass(generateAdapter = true)
data class ActivitySubscription(
    val allowSubscriptions: String? = null
)

@JsonClass(generateAdapter = true)
data class ProfileViewer(
    var muted: Boolean? = null,
    var blockedBy: Boolean? = null,
    var following: String? = null,
    var followedBy: String? = null
)

@JsonClass(generateAdapter = true)
data class Label(
    val src: String? = null,
    val uri: String? = null,
    val cid: String? = null,
    val val: String? = null,
    val cts: String? = null
)

// MARK: - Reply Reference Models

@JsonClass(generateAdapter = true)
data class ReplyRef(
    val root: PostRef,
    val parent: PostRef
)

@JsonClass(generateAdapter = true)
data class PostRef(
    val uri: String,
    val cid: String
)

// MARK: - Profile Models

@JsonClass(generateAdapter = true)
data class Profile(
    val did: String,
    val handle: String,
    val displayName: String? = null,
    val description: String? = null,
    val avatar: String? = null,
    val banner: String? = null,
    val followsCount: Int? = null,
    var followersCount: Int? = null,
    val postsCount: Int? = null,
    val indexedAt: String? = null,
    val createdAt: String? = null,
    val associated: AuthorAssociated? = null,
    var viewer: ProfileViewer? = null,
    val pinnedPost: StrongRef? = null,
    val labels: List<Label>? = null,
    val joinedViaStarterPack: JoinedViaStarterPack? = null
) {
    val id: String get() = did

    fun canReceiveMessagesFrom(currentUserFollowsThem: Boolean): Boolean {
        val allowIncoming = associated?.chat?.allowIncoming ?: return currentUserFollowsThem

        return when (allowIncoming) {
            "all" -> true
            "following" -> currentUserFollowsThem
            "none" -> false
            else -> currentUserFollowsThem
        }
    }
}

@JsonClass(generateAdapter = true)
data class JoinedViaStarterPack(
    val uri: String,
    val cid: String? = null,
    val value: StarterPackViewBasic? = null
)

@JsonClass(generateAdapter = true)
data class StarterPackViewBasic(
    val uri: String,
    val cid: String,
    val record: StarterPackRecord? = null,
    val creator: Author? = null,
    val listItemCount: Int? = null,
    val joinedWeekCount: Int? = null,
    val joinedAllTimeCount: Int? = null,
    val labels: List<Label>? = null,
    val indexedAt: String? = null
)

@JsonClass(generateAdapter = true)
data class StarterPackRecord(
    val name: String? = null,
    val description: String? = null,
    val createdAt: String? = null
)

// MARK: - List Models

@JsonClass(generateAdapter = true)
data class ListResponse(
    val list: ListView,
    val items: List<ListItemView>,
    val cursor: String? = null
)

@JsonClass(generateAdapter = true)
data class ActorListsResponse(
    val lists: List<ListView>,
    val cursor: String? = null
)

@JsonClass(generateAdapter = true)
data class ListView(
    val uri: String,
    val cid: String,
    val creator: Author,
    val name: String,
    val purpose: String,
    val description: String? = null,
    val indexedAt: String,
    val listItemCount: Int? = null
) {
    val id: String get() = uri
}

@JsonClass(generateAdapter = true)
data class ListItemView(
    val uri: String,
    val subject: Author
) {
    val id: String get() = uri
}

// MARK: - Feed Generator Models

@JsonClass(generateAdapter = true)
data class FeedGeneratorsResponse(
    val feeds: List<FeedGenerator>
)

@JsonClass(generateAdapter = true)
data class FeedGenerator(
    val uri: String,
    val cid: String,
    val did: String,
    val creator: Author,
    val displayName: String,
    val description: String? = null,
    val avatar: String? = null,
    val likeCount: Int? = null,
    val indexedAt: String? = null
) {
    val id: String get() = uri
}
