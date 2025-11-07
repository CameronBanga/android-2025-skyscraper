//
//  ChatModels.swift
//  Skyscraper
//
//  Models for Bluesky Chat (Direct Messages)
//

import Foundation

// MARK: - Conversation

struct ConvoView: Codable, Identifiable, Equatable {
    let id: String
    let rev: String
    let members: [ConvoMember]
    let lastMessage: MessageUnion?
    let muted: Bool
    let unreadCount: Int

    static func == (lhs: ConvoView, rhs: ConvoView) -> Bool {
        lhs.id == rhs.id &&
        lhs.rev == rhs.rev &&
        lhs.unreadCount == rhs.unreadCount
    }

    var otherMembers: [ConvoMember] {
        // Filter out the current user
        members.filter { !$0.did.contains(ATProtoClient.shared.session?.did ?? "") }
    }

    var displayName: String {
        let others = otherMembers
        if others.count == 1, let member = others.first {
            return member.displayName ?? member.handle
        } else if others.count > 1 {
            return others.map { $0.displayName ?? $0.handle }.prefix(2).joined(separator: ", ")
        }
        return "Conversation"
    }

    var displayHandle: String? {
        let others = otherMembers
        if others.count == 1, let member = others.first {
            return "@\(member.handle)"
        }
        return nil
    }

    var avatarURL: URL? {
        otherMembers.first?.avatar.flatMap { URL(string: $0) }
    }
}

struct ConvoMember: Codable, Identifiable {
    let did: String
    let handle: String
    let displayName: String?
    let avatar: String?
    let associated: Associated?

    var id: String { did }

    struct Associated: Codable {
        let chat: ChatAssociated?

        struct ChatAssociated: Codable {
            let allowIncoming: String
        }
    }
}

// MARK: - Messages

struct MessageSender: Codable, Identifiable {
    let did: String

    var id: String { did }
}

enum MessageUnion: Codable {
    case messageView(MessageView)
    case deletedMessageView(DeletedMessageView)

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        let singleValueContainer = try decoder.singleValueContainer()

        switch type {
        case "chat.bsky.convo.defs#messageView":
            let messageView = try singleValueContainer.decode(MessageView.self)
            self = .messageView(messageView)
        case "chat.bsky.convo.defs#deletedMessageView":
            let deletedView = try singleValueContainer.decode(DeletedMessageView.self)
            self = .deletedMessageView(deletedView)
        default:
            throw DecodingError.dataCorruptedError(
                in: singleValueContainer,
                debugDescription: "Unable to decode MessageUnion with type: \(type)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .messageView(let view):
            try container.encode(view)
        case .deletedMessageView(let view):
            try container.encode(view)
        }
    }

    var id: String {
        switch self {
        case .messageView(let view):
            return view.id
        case .deletedMessageView(let view):
            return view.id
        }
    }

    var sentAt: String {
        switch self {
        case .messageView(let view):
            return view.sentAt
        case .deletedMessageView(let view):
            return view.sentAt
        }
    }
}

struct MessageView: Codable, Identifiable {
    let id: String
    let rev: String
    let text: String?
    let facets: [Facet]?
    let embed: MessageEmbed?
    let sender: MessageSender
    let sentAt: String

    private enum CodingKeys: String, CodingKey {
        case id, rev, text, facets, embed, sender, sentAt
    }

    var sentAtDate: Date {
        ISO8601DateFormatter().date(from: sentAt) ?? Date()
    }
}

struct DeletedMessageView: Codable, Identifiable {
    let id: String
    let rev: String
    let sender: MessageSender
    let sentAt: String

    private enum CodingKeys: String, CodingKey {
        case id, rev, sender, sentAt
    }

    var sentAtDate: Date {
        ISO8601DateFormatter().date(from: sentAt) ?? Date()
    }
}

struct MessageEmbed: Codable {
    let record: EmbedRecord?

    struct EmbedRecord: Codable {
        let uri: String
        let cid: String
    }
}

// MARK: - Message Input

struct MessageInput: Codable {
    let text: String
    let facets: [Facet]?
    let embed: MessageEmbed?

    init(text: String, facets: [Facet]? = nil, embed: MessageEmbed? = nil) {
        self.text = text
        self.facets = facets
        self.embed = embed
    }
}

// MARK: - API Responses

struct ListConvosResponse: Codable {
    let cursor: String?
    let convos: [ConvoView]
}

struct GetConvoResponse: Codable {
    let convo: ConvoView
}

struct GetConvoForMembersResponse: Codable {
    let convo: ConvoView
}

struct SendMessageResponse: Codable {
    let id: String
    let rev: String
    let text: String?
    let facets: [Facet]?
    let embed: MessageEmbed?
    let sender: MessageSender
    let sentAt: String
}

struct GetMessagesResponse: Codable {
    let cursor: String?
    let messages: [MessageUnion]
}

// MARK: - Availability

struct GetConvoAvailabilityResponse: Codable {
    let status: String
}
