package com.cameronbanga.skyscraper.models

import com.squareup.moshi.JsonClass

// MARK: - Reply Restriction

sealed class ReplyRestriction {
    object Everybody : ReplyRestriction()
    object Nobody : ReplyRestriction()
    object Mentioned : ReplyRestriction()
    object Following : ReplyRestriction()
    object Followers : ReplyRestriction()
    data class Combined(
        val mentioned: Boolean,
        val following: Boolean,
        val followers: Boolean
    ) : ReplyRestriction()

    val displayName: String
        get() = when (this) {
            is Everybody -> "Everyone can interact"
            is Nobody -> "Nobody can reply"
            is Mentioned -> "Mentioned users"
            is Following -> "Users you follow"
            is Followers -> "Your followers"
            is Combined -> {
                val parts = mutableListOf<String>()
                if (mentioned) parts.add("Mentioned")
                if (following) parts.add("Following")
                if (followers) parts.add("Followers")
                parts.joinToString(" + ")
            }
        }

    val shortDisplayName: String
        get() = when (this) {
            is Everybody -> "Everyone can interact"
            else -> "Limited replies"
        }
}

// MARK: - Post Moderation Settings

@JsonClass(generateAdapter = true)
data class PostModerationSettings(
    var allowQuotePosts: Boolean = true,
    var replyRestrictionType: String = "everybody",  // Simplified for JSON storage
    var replyRestrictionMentioned: Boolean = false,
    var replyRestrictionFollowing: Boolean = false,
    var replyRestrictionFollowers: Boolean = false
) {
    var replyRestriction: ReplyRestriction
        get() = when (replyRestrictionType) {
            "everybody" -> ReplyRestriction.Everybody
            "nobody" -> ReplyRestriction.Nobody
            "mentioned" -> ReplyRestriction.Mentioned
            "following" -> ReplyRestriction.Following
            "followers" -> ReplyRestriction.Followers
            "combined" -> ReplyRestriction.Combined(
                mentioned = replyRestrictionMentioned,
                following = replyRestrictionFollowing,
                followers = replyRestrictionFollowers
            )
            else -> ReplyRestriction.Everybody
        }
        set(value) {
            when (value) {
                is ReplyRestriction.Everybody -> replyRestrictionType = "everybody"
                is ReplyRestriction.Nobody -> replyRestrictionType = "nobody"
                is ReplyRestriction.Mentioned -> replyRestrictionType = "mentioned"
                is ReplyRestriction.Following -> replyRestrictionType = "following"
                is ReplyRestriction.Followers -> replyRestrictionType = "followers"
                is ReplyRestriction.Combined -> {
                    replyRestrictionType = "combined"
                    replyRestrictionMentioned = value.mentioned
                    replyRestrictionFollowing = value.following
                    replyRestrictionFollowers = value.followers
                }
            }
        }

    val displaySummary: String
        get() {
            if (allowQuotePosts && replyRestriction is ReplyRestriction.Everybody) {
                return "Everyone can interact"
            } else if (!allowQuotePosts && replyRestriction is ReplyRestriction.Nobody) {
                return "No interactions"
            } else {
                val parts = mutableListOf<String>()
                if (!allowQuotePosts) {
                    parts.add("No quotes")
                }
                if (replyRestriction !is ReplyRestriction.Everybody) {
                    parts.add(replyRestriction.shortDisplayName)
                }
                return if (parts.isEmpty()) "Everyone can interact" else parts.joinToString(", ")
            }
        }

    companion object {
        val default = PostModerationSettings(
            allowQuotePosts = true,
            replyRestrictionType = "everybody"
        )
    }
}
