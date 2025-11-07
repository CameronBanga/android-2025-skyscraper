//
//  Analytics.swift
//  Skyscraper
//
//  Analytics wrapper that conditionally uses Firebase in Release builds only
//

import Foundation

#if !DEBUG
import FirebaseAnalytics
import FirebaseCrashlytics
#else
// Define Firebase constants for Debug builds to avoid compilation errors
let AnalyticsEventLogin = "login"
let AnalyticsParameterMethod = "method"
let AnalyticsEventScreenView = "screen_view"
let AnalyticsParameterScreenName = "screen_name"
let AnalyticsParameterScreenClass = "screen_class"
#endif

enum Analytics {
    /// Log an analytics event
    static func logEvent(_ name: String, parameters: [String: Any]? = nil) {
        #if !DEBUG
        FirebaseAnalytics.Analytics.logEvent(name, parameters: parameters)
        #else
        print("📊 [Analytics - Debug] Event: \(name), Parameters: \(parameters ?? [:])")
        #endif
    }

    /// Set user property
    static func setUserProperty(_ value: String?, forName name: String) {
        #if !DEBUG
        FirebaseAnalytics.Analytics.setUserProperty(value, forName: name)
        #else
        print("📊 [Analytics - Debug] User Property: \(name) = \(value ?? "nil")")
        #endif
    }

    /// Log screen view
    static func logScreenView(_ screenName: String, screenClass: String? = nil) {
        #if !DEBUG
        FirebaseAnalytics.Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName,
            AnalyticsParameterScreenClass: screenClass ?? screenName
        ])
        #else
        print("📊 [Analytics - Debug] Screen View: \(screenName)")
        #endif
    }

    /// Record a non-fatal error in Crashlytics
    static func recordError(_ error: Error, userInfo: [String: Any]? = nil) {
        #if !DEBUG
        Crashlytics.crashlytics().record(error: error, userInfo: userInfo)
        #else
        print("🔥 [Crashlytics - Debug] Error: \(error), UserInfo: \(userInfo ?? [:])")
        #endif
    }

    /// Set user identifier for crash reports
    static func setUserIdentifier(_ identifier: String?) {
        #if !DEBUG
        Crashlytics.crashlytics().setUserID(identifier)
        #else
        print("🔥 [Crashlytics - Debug] User ID: \(identifier ?? "nil")")
        #endif
    }
}
