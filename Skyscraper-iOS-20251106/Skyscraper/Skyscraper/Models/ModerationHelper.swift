//
//  ModerationHelper.swift
//  Skyscraper
//
//  Helper functions for content moderation
//

import Foundation

enum ModerationAction {
    case allow
    case warn
    case hide
}

extension Post {
    /// Check if this post should be moderated based on current settings
    func moderationAction(settings: ModerationSettings) -> ModerationAction {
        // Check if post contains muted words
        if containsMutedWords(settings.mutedWords) {
            return .hide
        }

        // Check labels on the post
        if let labels = self.labels {
            for label in labels {
                if let val = label.val, let contentLabel = ContentLabel(rawValue: val) {
                    let visibility = settings.visibility(for: contentLabel)

                    // If adult content is disabled, hide all adult content
                    if !settings.adultContentEnabled && isAdultLabel(contentLabel) {
                        return .hide
                    }

                    switch visibility {
                    case .hide:
                        return .hide
                    case .warn:
                        return .warn
                    case .show:
                        continue
                    }
                }
            }
        }

        // Check author labels
        if let authorLabels = self.author.labels {
            for label in authorLabels {
                if let val = label.val, let contentLabel = ContentLabel(rawValue: val) {
                    let visibility = settings.visibility(for: contentLabel)

                    switch visibility {
                    case .hide:
                        return .hide
                    case .warn:
                        return .warn
                    case .show:
                        continue
                    }
                }
            }
        }

        return .allow
    }

    /// Check if post text contains any muted words
    private func containsMutedWords(_ mutedWords: [String]) -> Bool {
        let postText = record.text.lowercased()

        for word in mutedWords {
            if postText.contains(word.lowercased()) {
                return true
            }
        }

        return false
    }

    /// Check if a label is adult content
    private func isAdultLabel(_ label: ContentLabel) -> Bool {
        switch label {
        case .sexual, .nudity, .porn:
            return true
        default:
            return false
        }
    }
}

extension FeedViewPost {
    /// Check if this feed post should be filtered based on feed settings
    func shouldBeFiltered(settings: ModerationSettings) -> Bool {
        // Check if reposts should be hidden
        if settings.hideReposts && reason != nil {
            return true
        }

        // Check if replies should be hidden
        if settings.hideReplies && reply != nil {
            return true
        }

        // Check if quote posts should be hidden
        if settings.hideQuotePosts && post.embed?.record != nil {
            return true
        }

        return false
    }

    /// Get the moderation action for this feed post
    func moderationAction(settings: ModerationSettings) -> ModerationAction {
        return post.moderationAction(settings: settings)
    }
}
