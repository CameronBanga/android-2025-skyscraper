//
//  ModerationSettings.swift
//  Skyscraper
//
//  Comprehensive moderation settings for Bluesky content
//

import Foundation
import Combine

// MARK: - Label Visibility Settings

enum LabelVisibility: String, Codable, CaseIterable {
    case hide = "hide"
    case warn = "warn"
    case show = "show"

    var displayName: String {
        switch self {
        case .hide: return "Hide"
        case .warn: return "Warn"
        case .show: return "Show"
        }
    }

    var description: String {
        switch self {
        case .hide: return "Content will be completely hidden"
        case .warn: return "Content will be shown with a warning"
        case .show: return "Content will be shown normally"
        }
    }
}

// MARK: - Content Labels

enum ContentLabel: String, Codable, CaseIterable {
    case sexual = "sexual"
    case nudity = "nudity"
    case porn = "porn"
    case nsfl = "nsfl"  // Not Safe For Life (graphic content)
    case gore = "gore"
    case violence = "violence"
    case hate = "hate"
    case spam = "spam"
    case impersonation = "impersonation"

    var displayName: String {
        switch self {
        case .sexual: return "Sexual Content"
        case .nudity: return "Nudity"
        case .porn: return "Pornography"
        case .nsfl: return "Graphic Media"
        case .gore: return "Gore"
        case .violence: return "Violence"
        case .hate: return "Hate Speech"
        case .spam: return "Spam"
        case .impersonation: return "Impersonation"
        }
    }

    var description: String {
        switch self {
        case .sexual: return "Sexually suggestive content"
        case .nudity: return "Content with nudity"
        case .porn: return "Pornographic content"
        case .nsfl: return "Disturbing or graphic media"
        case .gore: return "Graphic violence or injury"
        case .violence: return "Violent content"
        case .hate: return "Hateful or discriminatory content"
        case .spam: return "Spam or unwanted content"
        case .impersonation: return "Impersonation or misleading identity"
        }
    }

    var defaultVisibility: LabelVisibility {
        switch self {
        case .sexual, .nudity:
            return .warn
        case .porn, .nsfl, .gore, .violence:
            return .hide
        case .hate, .spam, .impersonation:
            return .warn
        }
    }
}

// MARK: - Moderation Settings

struct ModerationSettings: Codable, Equatable {
    var adultContentEnabled: Bool
    var labelPreferences: [String: String]  // ContentLabel.rawValue -> LabelVisibility.rawValue
    var mutedWords: [String]
    var hideReposts: Bool
    var hideReplies: Bool
    var hideQuotePosts: Bool

    static let `default` = ModerationSettings(
        adultContentEnabled: false,
        labelPreferences: [:],
        mutedWords: [],
        hideReposts: false,
        hideReplies: false,
        hideQuotePosts: false
    )

    func visibility(for label: ContentLabel) -> LabelVisibility {
        if let visibilityString = labelPreferences[label.rawValue],
           let visibility = LabelVisibility(rawValue: visibilityString) {
            return visibility
        }
        return label.defaultVisibility
    }

    mutating func setVisibility(_ visibility: LabelVisibility, for label: ContentLabel) {
        labelPreferences[label.rawValue] = visibility.rawValue
    }
}

// MARK: - Muted Word

struct MutedWord: Identifiable, Codable, Equatable {
    let id: UUID
    var value: String
    var targets: [String]  // ["content", "tag"]
    var actorTarget: String  // "all" or "exclude-following"
    var expiresAt: Date?

    init(value: String, targets: [String] = ["content"], actorTarget: String = "all", expiresAt: Date? = nil) {
        self.id = UUID()
        self.value = value
        self.targets = targets
        self.actorTarget = actorTarget
        self.expiresAt = expiresAt
    }

    var isExpired: Bool {
        if let expiresAt = expiresAt {
            return Date() > expiresAt
        }
        return false
    }
}

// MARK: - Preferences

@MainActor
class ModerationPreferences: ObservableObject {
    static let shared = ModerationPreferences()
    private let defaults = UserDefaults.standard
    private let baseModerationKey = "moderationSettings"
    private var isSyncing = false  // Prevent save loops

    @Published var settings: ModerationSettings {
        didSet {
            if !isSyncing {
                saveSettings()
            }
        }
    }

    private init() {
        // Load settings for the active account (from local cache first)
        self.settings = Self.loadSettings(for: AccountManager.shared.activeAccountId)

        // Fetch from server in background
        Task {
            await fetchFromServer()
        }

        // Observe account switches to reload settings
        NotificationCenter.default.addObserver(
            forName: .accountDidSwitch,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.reloadSettings()
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Manually sync settings from server (call this after login or when needed)
    func syncFromServer() async {
        await fetchFromServer()
    }

    /// Gets the UserDefaults key for the given account ID
    private func moderationKey(for accountId: String?) -> String {
        if let accountId = accountId {
            return "\(baseModerationKey)_\(accountId)"
        }
        return baseModerationKey
    }

    /// Loads settings for the specified account ID
    private static func loadSettings(for accountId: String?) -> ModerationSettings {
        let defaults = UserDefaults.standard
        let key = accountId != nil ? "moderationSettings_\(accountId!)" : "moderationSettings"

        if let data = defaults.data(forKey: key),
           let settings = try? JSONDecoder().decode(ModerationSettings.self, from: data) {
            return settings
        }
        return .default
    }

    /// Reloads settings when the active account changes
    private func reloadSettings() async {
        // Load from local cache first
        let cachedSettings = Self.loadSettings(for: AccountManager.shared.activeAccountId)
        isSyncing = true
        self.settings = cachedSettings
        isSyncing = false

        // Fetch from server
        await fetchFromServer()
    }

    /// Fetches moderation preferences from server
    private func fetchFromServer() async {
        guard let session = ATProtoClient.shared.session else {
            AppLogger.debug("No session, skipping server fetch", subsystem: "Moderation")
            return
        }

        do {
            let response = try await ATProtoClient.shared.getPreferences()
            let serverSettings = convertFromPreferences(response.preferences)

            isSyncing = true
            self.settings = serverSettings
            isSyncing = false

            // Cache locally
            saveToCache()

            AppLogger.info("Synced moderation settings from server", subsystem: "Moderation")
        } catch {
            AppLogger.error("Failed to fetch moderation settings from server", error: error, subsystem: "Moderation")
        }
    }

    /// Saves settings to both local cache and server
    private func saveSettings() {
        // Save to local cache
        saveToCache()

        // Save to server
        Task {
            await saveToServer()
        }
    }

    /// Saves to local UserDefaults cache
    private func saveToCache() {
        let key = moderationKey(for: AccountManager.shared.activeAccountId)
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: key)
        }
    }

    /// Saves moderation preferences to server
    private func saveToServer() async {
        guard ATProtoClient.shared.session != nil else {
            AppLogger.debug("No session, skipping server save", subsystem: "Moderation")
            return
        }

        do {
            // Get current preferences from server
            let response = try await ATProtoClient.shared.getPreferences()

            // Update only moderation preferences, keep other preferences intact
            var allPreferences = response.preferences.filter { pref in
                switch pref {
                case .adultContent, .contentLabel:
                    return false  // Remove old moderation prefs
                default:
                    return true  // Keep other prefs
                }
            }

            // Add our moderation preferences
            allPreferences.append(contentsOf: convertToPreferences(settings))

            // Save back to server
            try await ATProtoClient.shared.putPreferences(preferences: allPreferences)

            AppLogger.info("Synced moderation settings to server", subsystem: "Moderation")
        } catch {
            AppLogger.error("Failed to save moderation settings to server", error: error, subsystem: "Moderation")
        }
    }

    /// Converts server preferences to our ModerationSettings
    private func convertFromPreferences(_ preferences: [Preference]) -> ModerationSettings {
        var settings = ModerationSettings.default

        for pref in preferences {
            switch pref {
            case .adultContent(let adultContentPref):
                settings.adultContentEnabled = adultContentPref.enabled

            case .contentLabel(let labelPref):
                settings.labelPreferences[labelPref.label] = labelPref.visibility

            default:
                break
            }
        }

        return settings
    }

    /// Converts our ModerationSettings to server preferences
    private func convertToPreferences(_ settings: ModerationSettings) -> [Preference] {
        var preferences: [Preference] = []

        // Adult content preference
        preferences.append(.adultContent(AdultContentPref(enabled: settings.adultContentEnabled)))

        // Label preferences
        for (label, visibility) in settings.labelPreferences {
            preferences.append(.contentLabel(ContentLabelPref(label: label, visibility: visibility)))
        }

        return preferences
    }
}
