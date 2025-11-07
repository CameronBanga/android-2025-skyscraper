package com.cameronbanga.skyscraper.models

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass
import java.time.Instant

// MARK: - Conversation Models

@JsonClass(generateAdapter = true)
data class ConvoView(
    val id: String,
    val rev: String,
    val members: List<ConvoMember>,
    val lastMessage: MessageUnion? = null,
    val muted: Boolean,
    val unreadCount: Int
) {
    fun otherMembers(currentUserDid: String?): List<ConvoMember> {
        return members.filter { !it.did.contains(currentUserDid ?: "") }
    }

    fun displayName(currentUserDid: String?): String {
        val others = otherMembers(currentUserDid)
        return when {
            others.size == 1 -> others.first().displayName ?: others.first().handle
            others.size > 1 -> others.take(2).joinToString(", ") { it.displayName ?: it.handle }
            else -> "Conversation"
        }
    }

    fun displayHandle(currentUserDid: String?): String? {
        val others = otherMembers(currentUserDid)
        return if (others.size == 1) {
            "@${others.first().handle}"
        } else null
    }

    fun avatarURL(currentUserDid: String?): String? {
        return otherMembers(currentUserDid).firstOrNull()?.avatar
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is ConvoView) return false
        return id == other.id && rev == other.rev && unreadCount == other.unreadCount
    }

    override fun hashCode(): Int {
        var result = id.hashCode()
        result = 31 * result + rev.hashCode()
        result = 31 * result + unreadCount
        return result
    }
}

@JsonClass(generateAdapter = true)
data class ConvoMember(
    val did: String,
    val handle: String,
    val displayName: String? = null,
    val avatar: String? = null,
    val associated: Associated? = null
) {
    @JsonClass(generateAdapter = true)
    data class Associated(
        val chat: ChatAssociated? = null
    ) {
        @JsonClass(generateAdapter = true)
        data class ChatAssociated(
            val allowIncoming: String
        )
    }
}

// MARK: - Message Models

@JsonClass(generateAdapter = true)
data class MessageSender(
    val did: String
)

/**
 * Polymorphic message union - can be either a regular message or deleted message
 */
@JsonClass(generateAdapter = true)
data class MessageUnion(
    @field:Json(name = "\$type") val type: String,
    // MessageView fields
    val id: String? = null,
    val rev: String? = null,
    val text: String? = null,
    val facets: List<Facet>? = null,
    val embed: MessageEmbed? = null,
    val sender: MessageSender? = null,
    val sentAt: String? = null
) {
    val messageId: String get() = id ?: ""
    val messageSentAt: String get() = sentAt ?: ""

    fun toMessageView(): MessageView? {
        if (type == "chat.bsky.convo.defs#messageView") {
            return MessageView(
                id = id ?: return null,
                rev = rev ?: return null,
                text = text,
                facets = facets,
                embed = embed,
                sender = sender ?: return null,
                sentAt = sentAt ?: return null
            )
        }
        return null
    }

    fun toDeletedMessageView(): DeletedMessageView? {
        if (type == "chat.bsky.convo.defs#deletedMessageView") {
            return DeletedMessageView(
                id = id ?: return null,
                rev = rev ?: return null,
                sender = sender ?: return null,
                sentAt = sentAt ?: return null
            )
        }
        return null
    }
}

@JsonClass(generateAdapter = true)
data class MessageView(
    val id: String,
    val rev: String,
    val text: String? = null,
    val facets: List<Facet>? = null,
    val embed: MessageEmbed? = null,
    val sender: MessageSender,
    val sentAt: String
) {
    val sentAtDate: Instant
        get() = try {
            Instant.parse(sentAt)
        } catch (e: Exception) {
            Instant.now()
        }
}

@JsonClass(generateAdapter = true)
data class DeletedMessageView(
    val id: String,
    val rev: String,
    val sender: MessageSender,
    val sentAt: String
) {
    val sentAtDate: Instant
        get() = try {
            Instant.parse(sentAt)
        } catch (e: Exception) {
            Instant.now()
        }
}

@JsonClass(generateAdapter = true)
data class MessageEmbed(
    val record: EmbedRecord? = null
) {
    @JsonClass(generateAdapter = true)
    data class EmbedRecord(
        val uri: String,
        val cid: String
    )
}

// MARK: - Message Input

@JsonClass(generateAdapter = true)
data class MessageInput(
    val text: String,
    val facets: List<Facet>? = null,
    val embed: MessageEmbed? = null
)

// MARK: - API Response Models

@JsonClass(generateAdapter = true)
data class ListConvosResponse(
    val cursor: String? = null,
    val convos: List<ConvoView>
)

@JsonClass(generateAdapter = true)
data class GetConvoResponse(
    val convo: ConvoView
)

@JsonClass(generateAdapter = true)
data class GetConvoForMembersResponse(
    val convo: ConvoView
)

@JsonClass(generateAdapter = true)
data class SendMessageResponse(
    val id: String,
    val rev: String,
    val text: String? = null,
    val facets: List<Facet>? = null,
    val embed: MessageEmbed? = null,
    val sender: MessageSender,
    val sentAt: String
)

@JsonClass(generateAdapter = true)
data class GetMessagesResponse(
    val cursor: String? = null,
    val messages: List<MessageUnion>
)

@JsonClass(generateAdapter = true)
data class GetConvoAvailabilityResponse(
    val status: String
)
