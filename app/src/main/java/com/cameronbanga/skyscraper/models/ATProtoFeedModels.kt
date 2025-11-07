package com.cameronbanga.skyscraper.models

import com.squareup.moshi.JsonClass

// MARK: - Feed Models

@JsonClass(generateAdapter = true)
data class FeedResponse(
    val feed: List<FeedViewPost>,
    val cursor: String? = null
)

@JsonClass(generateAdapter = true)
data class FeedViewPost(
    val post: Post,
    val reply: ReplyContext? = null,
    val reason: FeedReason? = null
) {
    val id: String get() {
        // Combine post URI with repost info for uniqueness
        return if (reason != null) {
            "${post.uri}_repost_${reason.by?.did ?: ""}"
        } else {
            post.uri
        }
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is FeedViewPost) return false
        return id == other.id &&
                post.viewer?.like == other.post.viewer?.like &&
                post.viewer?.repost == other.post.viewer?.repost
    }

    override fun hashCode(): Int {
        var result = id.hashCode()
        result = 31 * result + (post.viewer?.like?.hashCode() ?: 0)
        result = 31 * result + (post.viewer?.repost?.hashCode() ?: 0)
        return result
    }
}

@JsonClass(generateAdapter = true)
data class ReplyContext(
    val root: Post? = null,
    val parent: Post? = null
)

@JsonClass(generateAdapter = true)
data class FeedReason(
    val by: Author? = null,
    val indexedAt: String? = null
)

// MARK: - Thread Models

@JsonClass(generateAdapter = true)
data class ThreadResponse(
    val thread: ThreadViewPostJson
)

/**
 * JSON representation of ThreadViewPost for decoding
 */
@JsonClass(generateAdapter = true)
data class ThreadViewPostJson(
    val post: Post,
    val parent: ThreadViewPostJson? = null,
    val replies: List<ThreadViewPostJson>? = null
) {
    val id: String get() = post.uri

    fun toThreadViewPost(): ThreadViewPost {
        return ThreadViewPost.PostThread(
            post = post,
            parent = parent?.toThreadViewPost(),
            replies = replies?.map { it.toThreadViewPost() }
        )
    }
}

/**
 * Sealed interface for thread view posts
 * Represents recursive thread structure
 */
sealed interface ThreadViewPost {
    val id: String
    val post: Post
    val parent: ThreadViewPost?
    val replies: List<ThreadViewPost>?

    data class PostThread(
        override val post: Post,
        override val parent: ThreadViewPost? = null,
        override val replies: List<ThreadViewPost>? = null
    ) : ThreadViewPost {
        override val id: String get() = post.uri
    }
}

// MARK: - Search Models

@JsonClass(generateAdapter = true)
data class SearchPostsResponse(
    val posts: List<Post>,
    val cursor: String? = null,
    val hitsTotal: Int? = null
)

@JsonClass(generateAdapter = true)
data class ActorSearchResponse(
    val actors: List<Profile>,
    val cursor: String? = null
)

// MARK: - Trending Topics Models

@JsonClass(generateAdapter = true)
data class TrendingTopicsResponse(
    val topics: List<TrendingTopic>
)

@JsonClass(generateAdapter = true)
data class TrendingTopic(
    val topic: String,
    val link: String? = null
) {
    val id: String get() = topic

    val hashtag: String get() = topic.removePrefix("#")
}
