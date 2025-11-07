//
//  ATProtoConstants.swift
//  Skyscraper
//
//  AT Protocol API limits and constants
//

import Foundation

/// Constants for AT Protocol API limits
enum ATProtoLimits {
    /// Maximum number of items that can be requested in a single API call
    enum Feed {
        static let maxSuggestedFeeds = 100
        static let maxTimelinePosts = 100
        static let maxFeedPosts = 100
    }

    enum Graph {
        static let maxFollows = 100
        static let maxFollowers = 100
    }

    enum Search {
        static let maxUsers = 100
        static let maxPosts = 100
    }

    /// Clamp a limit value to the maximum allowed
    static func clampFeedLimit(_ limit: Int, max: Int) -> Int {
        if limit > max {
            print("⚠️ Requested limit (\(limit)) exceeds maximum (\(max)), clamping to \(max)")
            return max
        }
        return limit
    }
}
