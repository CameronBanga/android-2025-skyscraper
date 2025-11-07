//
//  Logger.swift
//  Skyscraper
//
//  Lightweight logging facility with build configuration support
//  - DEBUG builds: Print to console with emoji indicators
//  - RELEASE builds: Use os.Logger for production diagnostics
//

import Foundation
import os.log

/// Unified logging system for the app
/// Usage: AppLogger.debug("Message"), AppLogger.info("Message"), etc.
enum AppLogger {

    // MARK: - Log Levels

    /// Debug-level logging (verbose, development only)
    static func debug(_ message: String, subsystem: String = "Timeline", file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, subsystem: subsystem, file: file, function: function, line: line)
    }

    /// Informational logging (general flow, non-critical events)
    static func info(_ message: String, subsystem: String = "Timeline", file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, subsystem: subsystem, file: file, function: function, line: line)
    }

    /// Warning-level logging (unexpected but recoverable situations)
    static func warning(_ message: String, subsystem: String = "Timeline", file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, subsystem: subsystem, file: file, function: function, line: line)
    }

    /// Error-level logging (failures, exceptions)
    static func error(_ message: String, error: Error? = nil, subsystem: String = "Timeline", file: String = #file, function: String = #function, line: Int = #line) {
        let errorMessage = error != nil ? "\(message) - Error: \(error!.localizedDescription)" : message
        log(errorMessage, level: .error, subsystem: subsystem, file: file, function: function, line: line)
    }

    // MARK: - Internal Implementation

    private enum LogLevel {
        case debug
        case info
        case warning
        case error

        var emoji: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            }
        }

        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            }
        }
    }

    private static func log(_ message: String, level: LogLevel, subsystem: String, file: String, function: String, line: Int) {
        let fileName = (file as NSString).lastPathComponent
        let location = "\(fileName):\(line) \(function)"

        #if DEBUG
        // Debug builds: Print to Xcode console with emoji and location
        print("\(level.emoji) [\(subsystem)] \(message) (\(location))")
        #else
        // Release builds: Use os.Logger for production diagnostics
        let logger = Logger(subsystem: "com.cameronbanga.Skyscraper.\(subsystem)", category: "app")
        let logMessage = "\(message) (\(location))"

        switch level {
        case .debug:
            logger.debug("\(logMessage, privacy: .public)")
        case .info:
            logger.info("\(logMessage, privacy: .public)")
        case .warning:
            logger.warning("\(logMessage, privacy: .public)")
        case .error:
            logger.error("\(logMessage, privacy: .public)")
        }
        #endif
    }
}

// MARK: - Specialized Loggers

/// Analytics-specific logging
enum AnalyticsLogger {
    static func logEvent(_ eventName: String, parameters: [String: Any]? = nil) {
        #if DEBUG
        let paramsString = parameters != nil ? ", Parameters: \(parameters!)" : ""
        AppLogger.debug("Analytics Event: \(eventName)\(paramsString)", subsystem: "Analytics")
        #endif
        // Note: Actual analytics events still go through Analytics.logEvent()
    }
}

/// Scroll position logging
enum ScrollLogger {
    static func saved(_ postURI: String, context: String = "") {
        AppLogger.debug("Saved scroll position\(context.isEmpty ? "" : " (\(context))"): \(postURI)", subsystem: "Scroll")
    }

    static func restored(_ postURI: String) {
        AppLogger.info("Restored scroll to: \(postURI)", subsystem: "Scroll")
    }
}

/// Account switching logging
enum AccountLogger {
    static func switched(to handle: String) {
        AppLogger.info("Account switched to: \(handle)", subsystem: "Account")
    }

    static func switchComplete() {
        AppLogger.info("Account switch complete", subsystem: "Account")
    }
}

/// Feed/Content logging
enum FeedLogger {
    static func changed(from: String?, to: String) {
        let fromText = from ?? "nil"
        AppLogger.info("Feed changed from \(fromText) to: \(to)", subsystem: "Feed")
    }

    static func insertingPosts(count: Int, locked: Bool) {
        let lockText = locked ? " with scroll lock" : ""
        AppLogger.debug("Auto-inserting \(count) post(s)\(lockText)", subsystem: "Feed")
    }

    static func fallback(_ message: String) {
        AppLogger.warning("Fallback: \(message)", subsystem: "Feed")
    }
}

/// Lifecycle logging
enum LifecycleLogger {
    static func appActive() {
        AppLogger.info("App active, started background fetching", subsystem: "Lifecycle")
    }

    static func appBackgrounded() {
        AppLogger.info("App backgrounded", subsystem: "Lifecycle")
    }
}
