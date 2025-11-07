//
//  SkyscraperApp.swift
//  Skyscraper
//
//  Created by Cameron Banga on 10/18/25.
//

import SwiftUI

// Only import Firebase for Release builds (speeds up Debug builds significantly)
#if !DEBUG
import FirebaseCore
import FirebaseAnalytics
import FirebaseCrashlytics
#endif

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@main
struct SkyscraperApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var appTheme = AppTheme.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Only configure Firebase for Release builds
        #if !DEBUG
        FirebaseApp.configure()
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        print("🔥 Firebase enabled for release builds")
        #else
        print("🔥 Firebase disabled for debug builds (faster compilation)")
        #endif

        // Configure URLCache for image prefetching
        // 100MB memory cache, 500MB disk cache
        let cache = URLCache(memoryCapacity: 100 * 1024 * 1024, diskCapacity: 500 * 1024 * 1024)
        URLCache.shared = cache

        // Apply keep screen awake setting on main thread
        DispatchQueue.main.async {
            let keepScreenAwake = UserDefaults.standard.bool(forKey: "keepScreenAwake")
            PlatformUtilities.isIdleTimerDisabled = keepScreenAwake
            print("🔆 Keep screen awake initialized: \(keepScreenAwake)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if authViewModel.isCheckingSession {
                    // Show splash screen while checking for saved session
                    ZStack {
                        // Use theme accent color for gradient
                        LinearGradient(
                            colors: [
                                appTheme.accentColor,
                                appTheme.accentColor.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .ignoresSafeArea()

                        VStack(spacing: 20) {
                            Image(systemName: "building.2")
                                .font(.system(size: 80))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)

                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.5)
                        }
                    }
                } else if authViewModel.isAuthenticated {
                    MainTabView()
                        .environmentObject(authViewModel)
                        .environmentObject(appTheme)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                } else {
                    LoginView()
                        .environmentObject(authViewModel)
                        .environmentObject(appTheme)
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: authViewModel.isAuthenticated)
            .animation(.easeInOut(duration: 0.3), value: authViewModel.isCheckingSession)
            .tint(appTheme.accentColor)
            .onChange(of: scenePhase) { oldPhase, newPhase in
                // Reapply keep screen awake setting when app becomes active
                if newPhase == .active {
                    let keepScreenAwake = UserDefaults.standard.bool(forKey: "keepScreenAwake")
                    PlatformUtilities.isIdleTimerDisabled = keepScreenAwake
                    print("🔆 Keep screen awake reapplied on active: \(keepScreenAwake)")
                }
            }
        }
        #if os(macOS)
        .defaultSize(width: 600, height: 900)
        .windowResizability(.contentSize)
        #endif
    }
}
