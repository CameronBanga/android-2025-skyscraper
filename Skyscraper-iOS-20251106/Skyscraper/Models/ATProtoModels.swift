//
//  ATProtoModels.swift
//  Skyscraper
//
//  Core ATProtocol data models
//

import Foundation

// MARK: - Authentication

struct ATProtoSession: Codable {
    let did: String
    let handle: String
    let email: String?
    let accessJwt: String
    let refreshJwt: String
    let pdsURL: String? // The PDS server URL for this session
}

struct CreateSessionRequest: Codable {
    let identifier: String
    let password: String
}

struct CreateSessionResponse: Codable {
    let did: String
    let handle: String
    let email: String?
    let accessJwt: String
    let refreshJwt: String
}

// MARK: - Post Models

struct Post: Identifiable, Codable {
    let uri: String
    let cid: String
    let author: Author
    let record: PostRecord
    let replyCount: Int?
    var repostCount: Int?
    var likeCount: Int?
    let quoteCount: Int?
    let bookmarkCount: Int?
    let indexedAt: String?
    var viewer: PostViewer?
    let embed: PostEmbed?
    let replyRef: ReplyRef?
    let labels: [Label]?

    var id: String { uri }
    var createdAt: Date {
        // Configure ISO8601DateFormatter to handle BlueSky's date format with fractional seconds
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: record.createdAt) {
            return date
        }

        // Fallback to formatter without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: record.createdAt) ?? Date()
    }

    enum CodingKeys: String, CodingKey {
        case uri, cid, author, record, replyCount, repostCount, likeCount, quoteCount, bookmarkCount
        case indexedAt, viewer, embed, labels
        case replyRef = "reply"
    }
}

struct PostRecord: Codable {
    let text: String
    let createdAt: String
    let facets: [Facet]?
    let langs: [String]?
    let tags: [String]?

    enum CodingKeys: String, CodingKey {
        case text, createdAt, facets, langs, tags
    }
}

struct Author: Codable, Identifiable {
    let did: String
    let handle: String?  // Optional - can be nil for deleted/suspended accounts
    let displayName: String?
    let description: String?
    let avatar: String?
    let associated: AuthorAssociated?
    var viewer: ProfileViewer?
    let labels: [Label]?
    let createdAt: String?

    var id: String { did }

    // Computed property for safe handle access with fallback
    var safeHandle: String {
        handle ?? "deleted.account"
    }

    // Computed property for short handle (username before first period)
    var shortHandle: String {
        let fullHandle = safeHandle
        if let firstPeriod = fullHandle.firstIndex(of: ".") {
            return String(fullHandle[..<firstPeriod])
        }
        return fullHandle
    }

    // Check if current user can send messages to this profile
    func canReceiveMessagesFrom(currentUserFollowsThem: Bool) -> Bool {
        guard let allowIncoming = associated?.chat?.allowIncoming else {
            // If no chat declaration, assume "following" as default
            return currentUserFollowsThem
        }

        switch allowIncoming {
        case "all":
            return true
        case "following":
            return currentUserFollowsThem
        case "none":
            return false
        default:
            return currentUserFollowsThem // Default to "following" for unknown values
        }
    }

    enum CodingKeys: String, CodingKey {
        case did, handle, displayName, description, avatar, associated, viewer, labels, createdAt
    }
}

struct AuthorAssociated: Codable {
    let activitySubscription: ActivitySubscription?
    let chat: ChatDeclaration?

    enum CodingKeys: String, CodingKey {
        case activitySubscription, chat
    }
}

struct ChatDeclaration: Codable {
    let allowIncoming: String // "all", "following", or "none"
}

struct ActivitySubscription: Codable {
    let allowSubscriptions: String?

    enum CodingKeys: String, CodingKey {
        case allowSubscriptions
    }
}

struct Label: Codable {
    let src: String?
    let uri: String?
    let cid: String?
    let val: String?
    let cts: String?
}

struct PostViewer: Codable {
    var like: String?
    var repost: String?
    let bookmarked: Bool?
    let threadMuted: Bool?
    let replyDisabled: Bool?
    let embeddingDisabled: Bool?
}

struct ProfileViewer: Codable {
    var muted: Bool?
    var blockedBy: Bool?
    var following: String?
    var followedBy: String?
}

// StrongRef for pinned posts (com.atproto.repo.strongRef)
struct StrongRef: Codable {
    let uri: String
    let cid: String
}

// MARK: - Embeds

// Post-level embed (from API response)
struct PostEmbed: Codable {
    let images: [ImageView]?
    let external: ExternalView?
    let record: EmbeddedPostRecord?
    let video: VideoView?
    let media: MediaEmbed?  // For recordWithMedia embeds

    enum CodingKeys: String, CodingKey {
        case type = "$type"
        case images, external, record, video, media
        // Video view properties (when embed IS the video)
        case cid, playlist, thumbnail, alt, aspectRatio
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Check the $type field to determine embed type
        let embedType = try? container.decode(String.self, forKey: .type)

        // Decode based on type
        switch embedType {
        case "app.bsky.embed.video#view":
            // Video view: the embed itself IS the video
            let cid = try? container.decode(String.self, forKey: .cid)
            let playlist = try container.decode(String.self, forKey: .playlist)
            let thumbnail = try? container.decode(String.self, forKey: .thumbnail)
            let alt = try? container.decode(String.self, forKey: .alt)
            let aspectRatio = try? container.decode(AspectRatio.self, forKey: .aspectRatio)

            video = VideoView(cid: cid, playlist: playlist, thumbnail: thumbnail, alt: alt, aspectRatio: aspectRatio)
            images = nil
            external = nil
            record = nil
            media = nil

        case "app.bsky.embed.images#view":
            images = try container.decode([ImageView].self, forKey: .images)
            external = nil
            record = nil
            video = nil
            media = nil

        case "app.bsky.embed.external#view":
            external = try container.decode(ExternalView.self, forKey: .external)
            images = nil
            record = nil
            video = nil
            media = nil

        case "app.bsky.embed.record#view":
            record = try container.decode(EmbeddedPostRecord.self, forKey: .record)
            images = nil
            external = nil
            video = nil
            media = nil

        case "app.bsky.embed.recordWithMedia#view":
            do {
                // The record in recordWithMedia is nested inside a wrapper with a "record" key
                // Structure: { "record": { "record": { actual post data } } }
                let wrapper = try container.decode([String: EmbeddedPostRecord].self, forKey: .record)
                record = wrapper["record"]
            } catch {
                record = nil
            }
            media = try container.decode(MediaEmbed.self, forKey: .media)
            images = nil
            external = nil
            video = nil

        default:
            // Fallback for older format without $type or #view suffix
            images = try container.decodeIfPresent([ImageView].self, forKey: .images)
            external = try container.decodeIfPresent(ExternalView.self, forKey: .external)
            record = try container.decodeIfPresent(EmbeddedPostRecord.self, forKey: .record)
            video = try container.decodeIfPresent(VideoView.self, forKey: .video)
            media = try container.decodeIfPresent(MediaEmbed.self, forKey: .media)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        if let video = video {
            try container.encode("app.bsky.embed.video#view", forKey: .type)
            try container.encodeIfPresent(video.cid, forKey: .cid)
            try container.encode(video.playlist, forKey: .playlist)
            try container.encodeIfPresent(video.thumbnail, forKey: .thumbnail)
            try container.encodeIfPresent(video.alt, forKey: .alt)
            try container.encodeIfPresent(video.aspectRatio, forKey: .aspectRatio)
        } else if let images = images {
            try container.encode("app.bsky.embed.images#view", forKey: .type)
            try container.encode(images, forKey: .images)
        } else if let external = external {
            try container.encode("app.bsky.embed.external#view", forKey: .type)
            try container.encode(external, forKey: .external)
        } else if let record = record, media == nil {
            try container.encode("app.bsky.embed.record#view", forKey: .type)
            try container.encode(record, forKey: .record)
        } else if let media = media {
            try container.encode("app.bsky.embed.recordWithMedia#view", forKey: .type)
            try container.encode(media, forKey: .media)
            try container.encodeIfPresent(record, forKey: .record)
        }
    }
}

// For handling recordWithMedia type embeds
struct MediaEmbed: Codable {
    let images: [ImageView]?
    let video: VideoView?
    let external: ExternalView?

    enum CodingKeys: String, CodingKey {
        case type = "$type"
        case images, video, external
        // Video view properties (when media IS the video)
        case cid, playlist, thumbnail, alt, aspectRatio
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let mediaType = try? container.decode(String.self, forKey: .type)

        switch mediaType {
        case "app.bsky.embed.video#view":
            // Video view: the media itself IS the video
            let cid = try? container.decode(String.self, forKey: .cid)
            let playlist = try container.decode(String.self, forKey: .playlist)
            let thumbnail = try? container.decode(String.self, forKey: .thumbnail)
            let alt = try? container.decode(String.self, forKey: .alt)
            let aspectRatio = try? container.decode(AspectRatio.self, forKey: .aspectRatio)

            video = VideoView(cid: cid, playlist: playlist, thumbnail: thumbnail, alt: alt, aspectRatio: aspectRatio)
            images = nil
            external = nil

        case "app.bsky.embed.images#view":
            images = try container.decode([ImageView].self, forKey: .images)
            video = nil
            external = nil

        case "app.bsky.embed.external#view":
            external = try container.decode(ExternalView.self, forKey: .external)
            images = nil
            video = nil

        default:
            images = try container.decodeIfPresent([ImageView].self, forKey: .images)
            video = try container.decodeIfPresent(VideoView.self, forKey: .video)
            external = try container.decodeIfPresent(ExternalView.self, forKey: .external)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let video = video {
            try container.encode("app.bsky.embed.video#view", forKey: .type)
            try container.encodeIfPresent(video.cid, forKey: .cid)
            try container.encode(video.playlist, forKey: .playlist)
            try container.encodeIfPresent(video.thumbnail, forKey: .thumbnail)
            try container.encodeIfPresent(video.alt, forKey: .alt)
            try container.encodeIfPresent(video.aspectRatio, forKey: .aspectRatio)
        } else if let images = images {
            try container.encode("app.bsky.embed.images#view", forKey: .type)
            try container.encode(images, forKey: .images)
        } else if let external = external {
            try container.encode("app.bsky.embed.external#view", forKey: .type)
            try container.encode(external, forKey: .external)
        }
    }
}

struct EmbeddedPostRecord: Codable {
    let type: String?
    let uri: String?
    let cid: String?
    let author: Author?
    let value: PostRecord?
    let labels: [Label]?
    let likeCount: Int?
    let replyCount: Int?
    let repostCount: Int?
    let quoteCount: Int?
    let indexedAt: String?
    let embeds: [PostEmbed]?

    enum CodingKeys: String, CodingKey {
        case type = "$type"
        case uri, cid, author, value, labels, likeCount, replyCount, repostCount, quoteCount, indexedAt, embeds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        type = try container.decodeIfPresent(String.self, forKey: .type)
        uri = try container.decodeIfPresent(String.self, forKey: .uri)
        cid = try container.decodeIfPresent(String.self, forKey: .cid)
        author = try container.decodeIfPresent(Author.self, forKey: .author)
        value = try container.decodeIfPresent(PostRecord.self, forKey: .value)
        labels = try container.decodeIfPresent([Label].self, forKey: .labels)
        likeCount = try container.decodeIfPresent(Int.self, forKey: .likeCount)
        replyCount = try container.decodeIfPresent(Int.self, forKey: .replyCount)
        repostCount = try container.decodeIfPresent(Int.self, forKey: .repostCount)
        quoteCount = try container.decodeIfPresent(Int.self, forKey: .quoteCount)
        indexedAt = try container.decodeIfPresent(String.self, forKey: .indexedAt)
        embeds = try container.decodeIfPresent([PostEmbed].self, forKey: .embeds)
    }
}

enum Embed: Codable {
    case images(ImagesEmbed)
    case external(ExternalEmbed)
    case record(RecordEmbed)

    enum CodingKeys: String, CodingKey {
        case type = "$type"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "app.bsky.embed.images":
            self = .images(try ImagesEmbed(from: decoder))
        case "app.bsky.embed.external":
            self = .external(try ExternalEmbed(from: decoder))
        case "app.bsky.embed.record":
            self = .record(try RecordEmbed(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown embed type: \(type)")
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .images(let embed):
            try embed.encode(to: encoder)
        case .external(let embed):
            try embed.encode(to: encoder)
        case .record(let embed):
            try embed.encode(to: encoder)
        }
    }
}

struct ImagesEmbed: Codable {
    let images: [ImageView]
}

struct ImageView: Codable, Identifiable {
    let thumb: String
    let fullsize: String
    let alt: String

    var id: String { fullsize }
}

struct VideoView: Codable, Identifiable {
    let cid: String?  // Content ID (required in view, but optional for compatibility)
    let playlist: String  // m3u8 URL for HLS streaming
    let thumbnail: String?
    let alt: String?
    let aspectRatio: AspectRatio?

    var id: String { playlist }
}

struct AspectRatio: Codable {
    let width: Int
    let height: Int
}

struct ExternalEmbed: Codable {
    let external: ExternalView
}

struct ExternalView: Codable {
    let uri: String
    let title: String
    let description: String
    let thumb: String?
}

struct RecordEmbed: Codable {
    let record: EmbeddedRecord
}

struct EmbeddedRecord: Codable {
    let uri: String
    let cid: String
}

// MARK: - Facets (for links, mentions, hashtags)

struct Facet: Codable {
    let index: ByteSlice
    let features: [Feature]
}

struct ByteSlice: Codable {
    let byteStart: Int
    let byteEnd: Int
}

enum Feature: Codable {
    case link(String)
    case mention(String)
    case tag(String)

    enum CodingKeys: String, CodingKey {
        case type = "$type"
        case uri
        case did
        case tag
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "app.bsky.richtext.facet#link":
            let uri = try container.decode(String.self, forKey: .uri)
            self = .link(uri)
        case "app.bsky.richtext.facet#mention":
            let did = try container.decode(String.self, forKey: .did)
            self = .mention(did)
        case "app.bsky.richtext.facet#tag":
            let tag = try container.decode(String.self, forKey: .tag)
            self = .tag(tag)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown feature type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .link(let uri):
            try container.encode("app.bsky.richtext.facet#link", forKey: .type)
            try container.encode(uri, forKey: .uri)
        case .mention(let did):
            try container.encode("app.bsky.richtext.facet#mention", forKey: .type)
            try container.encode(did, forKey: .did)
        case .tag(let tag):
            try container.encode("app.bsky.richtext.facet#tag", forKey: .type)
            try container.encode(tag, forKey: .tag)
        }
    }
}

// MARK: - Reply Reference

struct ReplyRef: Codable {
    let root: PostRef
    let parent: PostRef
}

struct PostRef: Codable {
    let uri: String
    let cid: String
}

// MARK: - Feed Response

struct FeedResponse: Codable {
    let feed: [FeedViewPost]
    let cursor: String?
}

struct FeedViewPost: Codable, Identifiable, Equatable {
    let post: Post
    let reply: ReplyContext?
    let reason: FeedReason?

    var id: String {
        // Create a unique ID by combining post URI with repost info if present
        if let reason = reason, let by = reason.by, let indexedAt = reason.indexedAt {
            return "\(post.uri)-repost-\(by.did)-\(indexedAt)"
        }
        return post.uri
    }

    static func == (lhs: FeedViewPost, rhs: FeedViewPost) -> Bool {
        lhs.id == rhs.id &&
        lhs.post.viewer?.like == rhs.post.viewer?.like &&
        lhs.post.viewer?.repost == rhs.post.viewer?.repost &&
        lhs.post.likeCount == rhs.post.likeCount &&
        lhs.post.repostCount == rhs.post.repostCount
    }
}

struct ReplyContext: Codable {
    let root: Post?
    let parent: Post?

    enum CodingKeys: String, CodingKey {
        case root, parent
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Try to decode root, but set to nil if it fails (e.g., blocked post)
        self.root = try? container.decode(Post.self, forKey: .root)

        // Try to decode parent, but set to nil if it fails (e.g., blocked post)
        self.parent = try? container.decode(Post.self, forKey: .parent)
    }
}

struct FeedReason: Codable {
    let by: Author?
    let indexedAt: String?

    enum CodingKeys: String, CodingKey {
        case by, indexedAt
    }
}

// MARK: - Search Posts Response

struct SearchPostsResponse: Codable {
    let posts: [Post]
    let cursor: String?
    let hitsTotal: Int?
}

// MARK: - Profile

struct Profile: Codable, Identifiable {
    let did: String
    let handle: String
    let displayName: String?
    let description: String?
    let avatar: String?
    let banner: String?
    let followsCount: Int?
    var followersCount: Int?  // Mutable for optimistic updates
    let postsCount: Int?
    let indexedAt: String?
    let createdAt: String?
    let associated: AuthorAssociated?
    var viewer: ProfileViewer?  // Mutable for optimistic updates
    let pinnedPost: StrongRef?  // Pinned post reference
    let labels: [Label]?
    let joinedViaStarterPack: JoinedViaStarterPack?

    var id: String { did }

    // Nested type for joinedViaStarterPack
    struct JoinedViaStarterPack: Codable {
        let uri: String
        let cid: String?
        let value: StarterPackViewBasic?
    }

    struct StarterPackViewBasic: Codable {
        let uri: String
        let cid: String
        let record: StarterPackRecord?
        let creator: Author?
        let listItemCount: Int?
        let joinedWeekCount: Int?
        let joinedAllTimeCount: Int?
        let labels: [Label]?
        let indexedAt: String?
    }

    struct StarterPackRecord: Codable {
        let name: String?
        let description: String?
        let createdAt: String?
    }

    // Check if current user can send messages to this profile
    func canReceiveMessagesFrom(currentUserFollowsThem: Bool) -> Bool {
        guard let allowIncoming = associated?.chat?.allowIncoming else {
            // If no chat declaration, assume "following" as default
            return currentUserFollowsThem
        }

        switch allowIncoming {
        case "all":
            return true
        case "following":
            return currentUserFollowsThem
        case "none":
            return false
        default:
            return currentUserFollowsThem // Default to "following" for unknown values
        }
    }
}

// MARK: - Thread

struct ThreadResponse: Codable {
    let thread: ThreadViewPost
}

indirect enum ThreadViewPost: Codable, Identifiable {
    case post(post: Post, parent: ThreadViewPost?, replies: [ThreadViewPost]?)

    var id: String {
        switch self {
        case .post(let post, _, _):
            return post.uri
        }
    }

    var post: Post {
        switch self {
        case .post(let post, _, _):
            return post
        }
    }

    var parent: ThreadViewPost? {
        switch self {
        case .post(_, let parent, _):
            return parent
        }
    }

    var replies: [ThreadViewPost]? {
        switch self {
        case .post(_, _, let replies):
            return replies
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let post = try container.decode(Post.self, forKey: .post)
        let parent = try container.decodeIfPresent(ThreadViewPost.self, forKey: .parent)
        let replies = try container.decodeIfPresent([ThreadViewPost].self, forKey: .replies)
        self = .post(post: post, parent: parent, replies: replies)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .post(let post, let parent, let replies):
            try container.encode(post, forKey: .post)
            try container.encodeIfPresent(parent, forKey: .parent)
            try container.encodeIfPresent(replies, forKey: .replies)
        }
    }

    enum CodingKeys: String, CodingKey {
        case post, parent, replies
    }
}

// MARK: - Feeds

struct PreferencesResponse: Codable {
    let preferences: [Preference]
}

enum Preference: Codable {
    case savedFeeds(SavedFeedsPref)
    case adultContent(AdultContentPref)
    case contentLabel(ContentLabelPref)
    case other([String: AnyCodable])

    enum CodingKeys: String, CodingKey {
        case type = "$type"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        if type == "app.bsky.actor.defs#savedFeedsPref" || type == "app.bsky.actor.defs#savedFeedsPrefV2" {
            self = .savedFeeds(try SavedFeedsPref(from: decoder))
        } else if type == "app.bsky.actor.defs#adultContentPref" {
            self = .adultContent(try AdultContentPref(from: decoder))
        } else if type == "app.bsky.actor.defs#contentLabelPref" {
            self = .contentLabel(try ContentLabelPref(from: decoder))
        } else {
            // For other preference types, store raw JSON
            let singleValueContainer = try decoder.singleValueContainer()
            let dict = try singleValueContainer.decode([String: AnyCodable].self)
            self = .other(dict)
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .savedFeeds(let pref):
            try pref.encode(to: encoder)
        case .adultContent(let pref):
            try pref.encode(to: encoder)
        case .contentLabel(let pref):
            try pref.encode(to: encoder)
        case .other(let dict):
            var container = encoder.singleValueContainer()
            try container.encode(dict)
        }
    }
}

struct SavedFeedsPref: Codable {
    let pinned: [String]
    let saved: [String]

    enum CodingKeys: String, CodingKey {
        case type = "$type"
        case pinned, saved, items
    }

    init(pinned: [String], saved: [String]) {
        self.pinned = pinned
        self.saved = saved
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        if type == "app.bsky.actor.defs#savedFeedsPrefV2" {
            // Handle V2 format with items array
            let items = try container.decode([SavedFeedItem].self, forKey: .items)

            var pinnedFeeds: [String] = []
            var allFeeds: [String] = []

            for item in items {
                if item.type == "feed", let value = item.value {
                    allFeeds.append(value)
                    if item.pinned == true {
                        pinnedFeeds.append(value)
                    }
                }
            }

            self.pinned = pinnedFeeds
            self.saved = allFeeds
        } else {
            // Handle V1 format with direct arrays
            self.pinned = try container.decodeIfPresent([String].self, forKey: .pinned) ?? []
            self.saved = try container.decodeIfPresent([String].self, forKey: .saved) ?? []
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("app.bsky.actor.defs#savedFeedsPref", forKey: .type)
        try container.encode(pinned, forKey: .pinned)
        try container.encode(saved, forKey: .saved)
    }
}

struct SavedFeedItem: Codable {
    let id: String?
    let type: String
    let value: String?
    let pinned: Bool?
}

// MARK: - Moderation Preferences

struct AdultContentPref: Codable {
    let enabled: Bool

    enum CodingKeys: String, CodingKey {
        case type = "$type"
        case enabled
    }

    init(enabled: Bool) {
        self.enabled = enabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.enabled = try container.decode(Bool.self, forKey: .enabled)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("app.bsky.actor.defs#adultContentPref", forKey: .type)
        try container.encode(enabled, forKey: .enabled)
    }
}

struct ContentLabelPref: Codable {
    let label: String
    let visibility: String  // "hide", "warn", or "show"

    enum CodingKeys: String, CodingKey {
        case type = "$type"
        case label
        case visibility
    }

    init(label: String, visibility: String) {
        self.label = label
        self.visibility = visibility
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.label = try container.decode(String.self, forKey: .label)
        self.visibility = try container.decode(String.self, forKey: .visibility)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("app.bsky.actor.defs#contentLabelPref", forKey: .type)
        try container.encode(label, forKey: .label)
        try container.encode(visibility, forKey: .visibility)
    }
}

struct FeedGeneratorsResponse: Codable {
    let feeds: [FeedGenerator]
}

struct FeedGenerator: Codable, Identifiable {
    let uri: String
    let cid: String
    let did: String
    let creator: Author
    let displayName: String
    let description: String?
    let avatar: String?
    let likeCount: Int?
    let indexedAt: String?

    var id: String { uri }
}

// MARK: - Lists

struct ListResponse: Codable {
    let list: ListView
    let items: [ListItemView]
    let cursor: String?
}

struct ActorListsResponse: Codable {
    let lists: [ListView]
    let cursor: String?
}

struct ListView: Codable, Identifiable {
    let uri: String
    let cid: String
    let creator: Author
    let name: String
    let purpose: String
    let description: String?
    let indexedAt: String
    let listItemCount: Int?

    var id: String { uri }
}

struct ListItemView: Codable, Identifiable {
    let uri: String
    let subject: Author

    var id: String { uri }
}

// Helper for decoding arbitrary JSON
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - Notifications

struct NotificationsResponse: Codable {
    let notifications: [Notification]
    let cursor: String?
}

struct Notification: Codable, Identifiable {
    let uri: String
    let cid: String?
    let author: Author
    let reason: String
    let reasonSubject: String?  // URI of the post that was liked/reposted/quoted
    let record: PostRecord?
    let isRead: Bool
    let indexedAt: String
    let labels: [Label]?

    var id: String { uri }

    enum CodingKeys: String, CodingKey {
        case uri, cid, author, reason, reasonSubject, record, isRead, indexedAt, labels
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uri = try container.decode(String.self, forKey: .uri)
        cid = try container.decodeIfPresent(String.self, forKey: .cid)
        author = try container.decode(Author.self, forKey: .author)
        reason = try container.decode(String.self, forKey: .reason)
        reasonSubject = try container.decodeIfPresent(String.self, forKey: .reasonSubject)
        // Only decode record as PostRecord if it's actually a post (for replies)
        // Other notification types (like, follow, repost) have different record types
        record = try? container.decodeIfPresent(PostRecord.self, forKey: .record)
        isRead = try container.decode(Bool.self, forKey: .isRead)
        indexedAt = try container.decode(String.self, forKey: .indexedAt)
        labels = try container.decodeIfPresent([Label].self, forKey: .labels)
    }
}

// MARK: - Trending Topics

struct TrendingTopicsResponse: Codable {
    let topics: [TrendingTopic]
}

struct TrendingTopic: Codable, Identifiable {
    let topic: String
    let link: String?

    var id: String { topic }

    // Extract hashtag from topic (remove # if present)
    var hashtag: String {
        topic.hasPrefix("#") ? String(topic.dropFirst()) : topic
    }
}
