//
//  PostModerationSettings.swift
//  Skyscraper
//
//  Post interaction and moderation settings
//

import Foundation

// MARK: - Reply Settings

enum ReplyRestriction: Equatable, Codable {
    case everybody
    case nobody
    case mentioned
    case following
    case followers
    case combined(mentioned: Bool, following: Bool, followers: Bool)

    var displayName: String {
        switch self {
        case .everybody:
            return "Everyone can interact"
        case .nobody:
            return "Nobody can reply"
        case .mentioned:
            return "Mentioned users"
        case .following:
            return "Users you follow"
        case .followers:
            return "Your followers"
        case .combined(let mentioned, let following, let followers):
            var parts: [String] = []
            if mentioned { parts.append("Mentioned") }
            if following { parts.append("Following") }
            if followers { parts.append("Followers") }
            return parts.joined(separator: " + ")
        }
    }

    var shortDisplayName: String {
        switch self {
        case .everybody:
            return "Everyone can interact"
        default:
            return "Limited replies"
        }
    }
}

// MARK: - Post Moderation Settings

struct PostModerationSettings: Codable, Equatable {
    var allowQuotePosts: Bool
    var replyRestriction: ReplyRestriction

    static let `default` = PostModerationSettings(
        allowQuotePosts: true,
        replyRestriction: .everybody
    )

    var displaySummary: String {
        if allowQuotePosts && replyRestriction == .everybody {
            return "Everyone can interact"
        } else if !allowQuotePosts && replyRestriction == .nobody {
            return "No interactions"
        } else {
            var parts: [String] = []
            if !allowQuotePosts {
                parts.append("No quotes")
            }
            if replyRestriction != .everybody {
                parts.append(replyRestriction.shortDisplayName)
            }
            return parts.isEmpty ? "Everyone can interact" : parts.joined(separator: ", ")
        }
    }
}

// MARK: - Preferences

@MainActor
class PostModerationPreferences {
    static let shared = PostModerationPreferences()
    private let defaults = UserDefaults.standard
    private let baseModerationKey = "defaultPostModerationSettings"

    var defaultSettings: PostModerationSettings {
        get {
            let key = moderationKey(for: AccountManager.shared.activeAccountId)
            if let data = defaults.data(forKey: key),
               let settings = try? JSONDecoder().decode(PostModerationSettings.self, from: data) {
                return settings
            }
            return .default
        }
        set {
            let key = moderationKey(for: AccountManager.shared.activeAccountId)
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: key)
            }
        }
    }

    /// Gets the UserDefaults key for the given account ID
    private func moderationKey(for accountId: String?) -> String {
        if let accountId = accountId {
            return "\(baseModerationKey)_\(accountId)"
        }
        return baseModerationKey
    }
}
