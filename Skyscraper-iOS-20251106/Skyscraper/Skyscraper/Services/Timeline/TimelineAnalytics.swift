//
//  TimelineAnalytics.swift
//  Skyscraper
//
//  Centralized analytics for timeline events
//

import Foundation

/// Wrapper for timeline-specific analytics events
struct TimelineAnalytics {
    /// Log timeline view event
    static func logTimelineViewed() {
        Analytics.logEvent("user_viewed_timeline", parameters: nil)
    }

    /// Log timeline refresh event
    static func logTimelineRefreshed() {
        Analytics.logEvent("user_refreshed_timeline", parameters: nil)
    }

    /// Log feed switch event
    static func logFeedSwitched(feedName: String) {
        Analytics.logEvent("user_switched_feed", parameters: [
            "feed_name": feedName
        ])
    }

    /// Log timeline load time
    static func logTimelineLoadTime(duration: TimeInterval, postCount: Int) {
        Analytics.logEvent("timeline_load_completed", parameters: [
            "duration_ms": Int(duration * 1000),
            "post_count": postCount
        ])
    }
}
