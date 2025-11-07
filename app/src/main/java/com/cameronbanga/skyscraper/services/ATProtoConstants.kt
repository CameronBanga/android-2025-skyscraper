package com.cameronbanga.skyscraper.services

/**
 * Constants for AT Protocol API limits
 */
object ATProtoLimits {
    object Feed {
        const val MAX_SUGGESTED_FEEDS = 100
        const val MAX_TIMELINE_POSTS = 100
        const val MAX_FEED_POSTS = 100
    }

    object Graph {
        const val MAX_FOLLOWS = 100
        const val MAX_FOLLOWERS = 100
    }

    object Search {
        const val MAX_USERS = 100
        const val MAX_POSTS = 100
    }

    fun clampFeedLimit(limit: Int, max: Int): Int {
        if (limit > max) {
            android.util.Log.w("ATProtoLimits", "Requested limit ($limit) exceeds maximum ($max), clamping to $max")
            return max
        }
        return limit
    }
}

/**
 * Base URLs for AT Protocol services
 */
object ATProtoUrls {
    const val DEFAULT_PDS = "https://bsky.social"
    const val CHAT_API = "https://api.bsky.chat"
    const val PUBLIC_API = "https://public.api.bsky.app"
}

/**
 * AT Protocol collection names
 */
object ATProtoCollections {
    const val POST = "app.bsky.feed.post"
    const val LIKE = "app.bsky.feed.like"
    const val REPOST = "app.bsky.feed.repost"
    const val FOLLOW = "app.bsky.graph.follow"
    const val THREADGATE = "app.bsky.feed.threadgate"
    const val POSTGATE = "app.bsky.feed.postgate"
}
