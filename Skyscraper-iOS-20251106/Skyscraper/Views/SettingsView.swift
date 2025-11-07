//
//  SettingsView.swift
//  Skyscraper
//
//  Settings and account management
//

import SwiftUI
import Combine

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - App Icon
enum AppIcon: String, CaseIterable, Identifiable {
    case orange = "AppIconOrange"
    case purple = "AppIconPurple"
    case teal = "AppIconTeal"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .orange: return "Orange"
        case .purple: return "Purple"
        case .teal: return "Teal"
        }
    }

    var iconName: String? {
        switch self {
        case .orange: return nil // nil = primary icon
        case .purple: return "app_icon_purple"
        case .teal: return "app_icon_teal"
        }
    }

    var color: Color {
        switch self {
        case .orange: return .orange
        case .purple: return .purple
        case .teal: return .teal
        }
    }

    var previewGradient: LinearGradient {
        switch self {
        case .orange:
            return LinearGradient(
                colors: [Color(red: 1.0, green: 0.553, blue: 0.157), Color(red: 1.0, green: 0.8, blue: 0.0)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .purple:
            return LinearGradient(
                colors: [Color(red: 0.796, green: 0.188, blue: 0.878), Color(red: 0.380, green: 0.333, blue: 0.961)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .teal:
            return LinearGradient(
                colors: [Color(red: 0.0, green: 0.8, blue: 0.8), Color(red: 0.0, green: 0.6, blue: 1.0)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    static var current: AppIcon {
        guard let iconName = PlatformUtilities.alternateIconName else {
            return .orange // nil means using primary icon
        }
        return AppIcon.allCases.first { $0.iconName == iconName } ?? .orange
    }
}

// MARK: - Refresh Interval
enum RefreshInterval: Int, CaseIterable, Identifiable {
    case oneSecond = 1
    case fiveSeconds = 5
    case fifteenSeconds = 15
    case thirtySeconds = 30
    case oneMinute = 60
    case fiveMinutes = 300
    case never = 0

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .oneSecond: return "1 Second"
        case .fiveSeconds: return "5 Seconds"
        case .fifteenSeconds: return "15 Seconds"
        case .thirtySeconds: return "30 Seconds"
        case .oneMinute: return "1 Minute"
        case .fiveMinutes: return "5 Minutes"
        case .never: return "Never"
        }
    }

    static var `default`: RefreshInterval { .thirtySeconds }
}

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var theme: AppTheme
    @StateObject private var viewModel = SettingsViewModel()
    @ObservedObject private var accountManager = AccountManager.shared
    @State private var showingAddAccount = false
    @Environment(\.dismiss) var dismiss

    // Check if current user is the developer
    private var isDeveloper: Bool {
        accountManager.activeAccount?.handle == "cameronbanga.com"
    }

    var body: some View {
        NavigationStack {
            List {
                // Developer Notes Section
                Section {
                    NavigationLink(destination: DeveloperNotesView()) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Developer Notes")
                                    .font(.body)
                                if let lastUpdated = viewModel.developerNotesLastUpdated {
                                    Text("Updated: \(lastUpdated)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }
                    }
                }

                // Account Section
                Section("Accounts") {
                    // List all accounts with checkboxes
                    ForEach(accountManager.accounts) { account in
                        HStack(spacing: 12) {
                            // Checkbox button
                            Button {
                                if account.id != accountManager.activeAccountId {
                                    accountManager.switchAccount(to: account.id)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    // Checkbox
                                    Image(systemName: account.id == accountManager.activeAccountId ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(account.id == accountManager.activeAccountId ? theme.accentColor : .secondary)
                                        .font(.title3)

                                    // Avatar and info
                                    AvatarImage(
                                        url: account.avatar.flatMap { URL(string: $0) },
                                        size: 48
                                    )

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(account.displayName ?? account.handle)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        Text("@\(account.handle)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.8)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .buttonStyle(.plain)

                            // Navigation to profile
                            NavigationLink(destination: ProfileView(actor: account.handle)) {
                                EmptyView()
                            }
                            .frame(width: 20)
                        }
                        .padding(.vertical, 4)
                    }

                    // Add Account Button
                    Button {
                        showingAddAccount = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Additional Account")
                        }
                        .foregroundStyle(theme.accentColor)
                    }
                }

                // Appearance Section
                Section("Appearance") {
                    NavigationLink(destination: AppIconPickerView(viewModel: viewModel)) {
                        HStack {
                            Text("App Icon")
                            Spacer()
                            HStack(spacing: 8) {
                                Text(viewModel.selectedAppIcon.displayName)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    NavigationLink(destination: ThemeColorPickerView()) {
                        HStack {
                            Text("Accent Color")
                            Spacer()
                            Circle()
                                .fill(theme.accentColor)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .strokeBorder(.gray.opacity(0.2), lineWidth: 1)
                                )
                        }
                    }
                }

                // Cache Section (Developer Only)
                if isDeveloper {
                    Section("Storage") {
                        if let cacheSize = viewModel.cacheSize {
                            HStack {
                                Text("Cache Size")
                                Spacer()
                                Text(cacheSize)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Button {
                            viewModel.clearCache()
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Clear Cache")
                            }
                        }
                        .disabled(viewModel.isLoadingCacheSize)
                    }
                }

                // Media Section
                Section("Media") {
                    Toggle(isOn: $viewModel.autoPlayVideos) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Auto-play Videos")
                            Text("Automatically play videos when they appear on screen")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(theme.accentColor)
                }

                // Development Features Section (Developer Only)
                if isDeveloper {
                    Section("Development Features") {
                        Toggle(isOn: $viewModel.keepScreenAwake) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Keep Screen Awake")
                                Text("Prevents the screen from sleeping while app is open")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tint(theme.accentColor)

                        Picker("Background Refresh", selection: $viewModel.refreshInterval) {
                            ForEach(RefreshInterval.allCases) { interval in
                                Text(interval.displayName).tag(interval)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                // About Section
                Section("About") {
                    NavigationLink(destination: AboutAppView()) {
                        HStack {
                            Image(systemName: "info.circle")
                            Text("About This App")
                        }
                    }

                    HStack {
                        Text("Version")
                        Spacer()
                        Text(viewModel.appVersion)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Build")
                        Spacer()
                        Text(viewModel.buildNumber)
                            .foregroundStyle(.secondary)
                    }

                    Link(destination: URL(string: "https://bsky.app")!) {
                        HStack {
                            Image(systemName: "link")
                            Text("BlueSky")
                            Spacer()
                            Image(systemName: "arrow.up.forward")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                }
            }
            #if os(macOS)
            .listStyle(.inset)
            .frame(minWidth: 600, minHeight: 500)
            #endif
            .navigationTitle("Settings")
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Close")
                            .foregroundStyle(theme.accentColor)
                    }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Close")
                            .foregroundStyle(theme.accentColor)
                    }
                }
                #endif
            }
            .task {
                // Only calculate cache size if user is the developer
                if isDeveloper {
                    await viewModel.calculateCacheSize()
                }
            }
            #if os(iOS)
            .fullScreenCover(isPresented: $showingAddAccount) {
                LoginView(isAddingAccount: true)
                    .environmentObject(authViewModel)
                    .environmentObject(theme)
            }
            #else
            .sheet(isPresented: $showingAddAccount) {
                LoginView(isAddingAccount: true)
                    .environmentObject(authViewModel)
                    .environmentObject(theme)
            }
            #endif
        }
        .tint(theme.accentColor)
    }
}

// MARK: - ViewModel
@MainActor
class SettingsViewModel: ObservableObject {
    @Published var cacheSize: String?
    @Published var isLoadingCacheSize = false
    @Published var selectedAppIcon: AppIcon = .current
    @Published var developerNotesLastUpdated: String?
    @Published var keepScreenAwake: Bool {
        didSet {
            UserDefaults.standard.set(keepScreenAwake, forKey: "keepScreenAwake")
            PlatformUtilities.isIdleTimerDisabled = keepScreenAwake
            print("🔆 Keep screen awake changed: \(keepScreenAwake)")
            // Post notification to update anywhere else that might need it
            NotificationCenter.default.post(name: .keepScreenAwakeDidChange, object: nil)
        }
    }

    @Published var refreshInterval: RefreshInterval {
        didSet {
            UserDefaults.standard.set(refreshInterval.rawValue, forKey: "backgroundRefreshInterval")
            print("Background refresh interval changed to: \(refreshInterval.displayName)")
            // Post notification to update the timeline refresh timer
            NotificationCenter.default.post(name: .refreshIntervalDidChange, object: nil)
        }
    }

    @Published var autoPlayVideos: Bool {
        didSet {
            UserDefaults.standard.set(autoPlayVideos, forKey: "autoPlayVideos")
            print("🎥 Auto-play videos changed: \(autoPlayVideos)")
            // Post notification so VideoPlayerView can update
            NotificationCenter.default.post(name: .autoPlayVideosDidChange, object: nil)
        }
    }

    private let cacheService = PostCacheService.shared

    init() {
        // Initialize properties without triggering didSet by using the property wrapper directly
        let savedKeepAwake = UserDefaults.standard.bool(forKey: "keepScreenAwake")
        _keepScreenAwake = Published(initialValue: savedKeepAwake)

        // Check if the key exists first, if not use default (30 seconds)
        if UserDefaults.standard.object(forKey: "backgroundRefreshInterval") != nil {
            let savedInterval = UserDefaults.standard.integer(forKey: "backgroundRefreshInterval")
            if let interval = RefreshInterval(rawValue: savedInterval) {
                _refreshInterval = Published(initialValue: interval)
            } else {
                _refreshInterval = Published(initialValue: .default)
            }
        } else {
            // First launch, use default 30 seconds
            _refreshInterval = Published(initialValue: .default)
        }

        // Initialize auto-play videos (default to ON if not set)
        if UserDefaults.standard.object(forKey: "autoPlayVideos") != nil {
            let savedAutoPlay = UserDefaults.standard.bool(forKey: "autoPlayVideos")
            _autoPlayVideos = Published(initialValue: savedAutoPlay)
        } else {
            // First launch, default to ON
            _autoPlayVideos = Published(initialValue: true)
            UserDefaults.standard.set(true, forKey: "autoPlayVideos")
        }

        // Apply the screen awake setting
        PlatformUtilities.isIdleTimerDisabled = savedKeepAwake

        // Load developer notes last updated date
        loadDeveloperNotesLastUpdated()
    }

    func loadDeveloperNotesLastUpdated() {
        guard let url = Bundle.main.url(forResource: "DeveloperNotes", withExtension: "md") else {
            return
        }

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let modificationDate = attributes[.modificationDate] as? Date {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .abbreviated
                developerNotesLastUpdated = formatter.localizedString(for: modificationDate, relativeTo: Date())
            }
        } catch {
            print("Error getting developer notes modification date: \(error)")
        }
    }

    func setAppIcon(_ icon: AppIcon) {
        guard PlatformUtilities.supportsAlternateIcons else {
            print("Alternate icons are not supported")
            return
        }

        Task { @MainActor in
            do {
                try await PlatformUtilities.setAlternateIconName(icon.iconName)
                selectedAppIcon = icon
                print("App icon changed to: \(icon.displayName)")
            } catch {
                print("Failed to change app icon: \(error.localizedDescription)")
            }
        }
    }

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

    func calculateCacheSize() async {
        isLoadingCacheSize = true

        // Get CoreData cache size across all feeds
        let cachedPosts = cacheService.loadAllCachedPosts()
        let postCount = cachedPosts.count

        // Estimate size (rough calculation)
        let estimatedSize = Double(postCount) * 50.0 // ~50KB per post estimate
        let sizeInMB = estimatedSize / 1024.0

        if sizeInMB > 1 {
            cacheSize = String(format: "%.1f MB (%d posts)", sizeInMB, postCount)
        } else {
            cacheSize = String(format: "%.0f KB (%d posts)", estimatedSize, postCount)
        }

        isLoadingCacheSize = false
    }

    func clearCache() {
        cacheService.clearCache()
        cacheService.clearAllScrollPositions()

        // Recalculate size
        Task {
            await calculateCacheSize()
        }
    }
}

// MARK: - App Icon Picker View
struct AppIconPickerView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @EnvironmentObject var theme: AppTheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(AppIcon.allCases) { icon in
                Button {
                    viewModel.setAppIcon(icon)
                    // Dismiss after a short delay to show the checkmark
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        dismiss()
                    }
                } label: {
                    HStack(spacing: 16) {
                        // Icon preview using actual rendered icon
                        AppIconPreview(icon: icon)
                            .frame(width: 60, height: 60)

                        // Icon name
                        Text(icon.displayName)
                            .font(.body)
                            .foregroundStyle(.primary)

                        Spacer()

                        // Checkmark for selected icon
                        if icon == viewModel.selectedAppIcon {
                            Image(systemName: "checkmark")
                                .foregroundStyle(theme.accentColor)
                                .fontWeight(.semibold)
                        }
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("App Icon")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - App Icon Preview
struct AppIconPreview: View {
    let icon: AppIcon

    var body: some View {
        Group {
            if let iconImage = getAppIconImage() {
                #if os(iOS)
                Image(uiImage: iconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(.black.opacity(0.1), lineWidth: 0.5)
                    )
                #elseif os(macOS)
                Image(nsImage: iconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(.black.opacity(0.1), lineWidth: 0.5)
                    )
                #endif
            } else {
                // Fallback if image can't be loaded
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(icon.color.gradient)

                    Image(systemName: "building.2.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white)
                }
                .frame(width: 60, height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(.black.opacity(0.1), lineWidth: 0.5)
                )
            }
        }
    }

    private func getAppIconImage() -> PlatformImage? {
        let imageName: String
        switch icon {
        case .orange:
            imageName = "app_icon_orange-iOS-Default-1024x1024@1x"
        case .purple:
            imageName = "app_icon_purple-iOS-Default-1024x1024@1x"
        case .teal:
            imageName = "app_icon_teal-iOS-Default-1024x1024@1x"
        }

        #if os(iOS)
        // Try loading from bundle by name
        if let image = UIImage(named: imageName) {
            return image
        }

        // Try with Icons/ prefix
        if let image = UIImage(named: "Icons/\(imageName)") {
            return image
        }

        // Try loading from file path in bundle
        if let bundlePath = Bundle.main.resourcePath {
            let iconPath = "\(bundlePath)/Icons/\(imageName).png"
            if let image = UIImage(contentsOfFile: iconPath) {
                return image
            }
        }
        #elseif os(macOS)
        // Try loading from bundle by name
        if let image = NSImage(named: imageName) {
            return image
        }

        // Try with Icons/ prefix
        if let image = NSImage(named: "Icons/\(imageName)") {
            return image
        }

        // Try loading from file path in bundle
        if let bundlePath = Bundle.main.resourcePath {
            let iconPath = "\(bundlePath)/Icons/\(imageName).png"
            if let image = NSImage(contentsOfFile: iconPath) {
                return image
            }
        }
        #endif

        return nil
    }
}

// MARK: - Notification Name
extension Foundation.Notification.Name {
    static let refreshIntervalDidChange = Foundation.Notification.Name("refreshIntervalDidChange")
    static let keepScreenAwakeDidChange = Foundation.Notification.Name("keepScreenAwakeDidChange")
    static let autoPlayVideosDidChange = Foundation.Notification.Name("autoPlayVideosDidChange")
}

#Preview {
    SettingsView()
}
