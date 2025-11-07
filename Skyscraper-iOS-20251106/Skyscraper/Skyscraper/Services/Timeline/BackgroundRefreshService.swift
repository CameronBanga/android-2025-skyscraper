//
//  BackgroundRefreshService.swift
//  Skyscraper
//
//  Protocol for background refresh of timeline
//

import Foundation

/// Service responsible for background refresh scheduling
protocol BackgroundRefreshService {
    /// Start background refresh with a given interval
    func startRefreshing(interval: TimeInterval, onRefresh: @escaping @Sendable () async -> Void) async

    /// Stop background refresh
    func stopRefreshing()

    /// Get the configured refresh interval from settings
    func getRefreshInterval() -> TimeInterval?
}

/// Default implementation using async/await Task loop
@MainActor
class DefaultBackgroundRefreshService: BackgroundRefreshService {
    private var refreshTask: Task<Void, Never>?

    func startRefreshing(interval: TimeInterval, onRefresh: @escaping @Sendable () async -> Void) async {
        // Stop any existing refresh task
        stopRefreshing()

        // Start new refresh loop
        refreshTask = Task {
            // Fire immediately for the first fetch
            await onRefresh()

            // Then continue with periodic fetches
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))

                guard !Task.isCancelled else { break }

                await onRefresh()
            }
        }
    }

    func stopRefreshing() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func getRefreshInterval() -> TimeInterval? {
        let savedInterval = UserDefaults.standard.integer(forKey: "backgroundRefreshInterval")

        // If saved interval is 0 (never), return nil
        if savedInterval == 0 {
            return nil
        } else if savedInterval > 0 {
            return TimeInterval(savedInterval)
        } else {
            // Default to 30 seconds if not set
            return 30
        }
    }
}
