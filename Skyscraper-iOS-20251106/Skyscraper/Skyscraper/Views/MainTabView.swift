//
//  MainTabView.swift
//  Skyscraper
//
//  Main tab bar container
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var appTheme: AppTheme
    @State private var selectedTab = 0
    @State private var showingComposer = false

    @ObservedObject private var client = ATProtoClient.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Timeline", systemImage: "house.fill", value: 0) {
                TimelineView()
            }

            Tab("Discover", systemImage: "sparkles", value: 1) {
                DiscoverView()
            }

            Tab("Activity", systemImage: "at", value: 2) {
                NotificationsView()
            }

            // Only show Chat tab if using bsky.social PDS
            if client.isChatAvailable {
                Tab("Chat", systemImage: "message.fill", value: 3) {
                    ChatListView()
                }
            }

            Tab("Compose", systemImage: "square.and.pencil", value: 99, role: .search) {
                Color.clear
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tint(appTheme.accentColor)
        #if os(macOS)
        .frame(minWidth: 700)
        #endif
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue == 99 {
                showingComposer = true
                // Reset back to previous tab
                selectedTab = oldValue
            }
        }
        .onChange(of: client.isChatAvailable) { _, isAvailable in
            // If chat becomes unavailable and user is on the Chat tab, switch to Timeline
            if !isAvailable && selectedTab == 3 {
                selectedTab = 0
            }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showingComposer) {
            PostComposerView { posted in
                if posted {
                    selectedTab = 0
                }
            }
        }
        #else
        .sheet(isPresented: $showingComposer) {
            PostComposerView { posted in
                if posted {
                    selectedTab = 0
                }
            }
        }
        #endif
    }
}

#Preview {
    MainTabView()
}
