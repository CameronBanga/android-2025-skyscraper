//
//  NewConversationView.swift
//  Skyscraper
//
//  Create new chat conversations
//

import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct NewConversationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var theme: AppTheme
    @State private var searchText = ""
    @State private var searchResults: [Profile] = []
    @State private var isSearching = false
    @State private var selectedConversation: ConvoView?
    @State private var isCreatingConversation = false
    @State private var navigateToChat = false
    @State private var errorMessage: String?
    @State private var showError = false

    private let client = ATProtoClient.shared

    var body: some View {
        let searchBarView = searchBar
        let contentView = mainContent

        return NavigationStack {
            VStack(spacing: 0) {
                searchBarView
                contentView
            }
            .navigationTitle("New Conversation")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .navigationDestination(isPresented: $navigateToChat) {
                if let conversation = selectedConversation {
                    ChatView(conversation: conversation)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if isCreatingConversation {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    ProgressView()
                        .tint(theme.accentColor)
                        .scaleEffect(1.5)
                }
            }
        }
        .onChange(of: searchText) { oldValue, newValue in
            if !newValue.isEmpty && newValue.count >= 2 {
                Task {
                    await searchUsers()
                }
            } else {
                searchResults = []
            }
        }
        .alert("Cannot Start Conversation", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search for users", text: $searchText)
                .textFieldStyle(.plain)
                #if os(iOS)
                .autocapitalization(.none)
                #endif
                .disableAutocorrection(true)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    searchResults = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        #if os(iOS)
        .background(Color(uiColor: .secondarySystemBackground))
        #else
        .background(Color(nsColor: .controlBackgroundColor))
        #endif
        .cornerRadius(10)
        .padding()
    }

    private var mainContent: some View {
        Group {
            if isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty && !searchText.isEmpty {
                emptySearchResults
            } else if searchResults.isEmpty {
                emptyState
            } else {
                userList
            }
        }
    }

    private var emptySearchResults: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("No users found")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("Search for users to start a conversation")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var userList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(searchResults) { user in
                    Button {
                        startConversation(with: user)
                    } label: {
                        UserSearchRow(user: user)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isCreatingConversation)

                    Divider()
                        .padding(.leading, 76)
                }
            }
        }
    }

    private func searchUsers() async {
        await performSearch(query: searchText)
    }

    private func performSearch(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true

        do {
            // Wait a bit to debounce
            try await Task.sleep(nanoseconds: 300_000_000)

            guard searchText == query else {
                return
            }

            var results: [Profile] = []
            var seenDIDs = Set<String>()

            // Get current user's DID
            guard let currentUserDID = client.session?.did else {
                isSearching = false
                return
            }

            // 1. Search follows (people you follow)
            do {
                let follows = try await client.getFollows(actor: currentUserDID, limit: 50)

                for profile in follows {
                    // Filter by query
                    if profile.handle.localizedCaseInsensitiveContains(query) ||
                       (profile.displayName?.localizedCaseInsensitiveContains(query) ?? false) {

                        if !seenDIDs.contains(profile.did) {
                            results.append(profile)
                            seenDIDs.insert(profile.did)
                        }
                    }
                }
                print("📍 Found \(results.count) matches in follows for '\(query)'")
            } catch {
                print("⚠️ Failed to search follows: \(error)")
            }

            guard searchText == query else { return }

            // 2. Search followers (people who follow you)
            do {
                let followers = try await client.getFollowers(actor: currentUserDID, limit: 50)

                for profile in followers {
                    // Filter by query
                    if profile.handle.localizedCaseInsensitiveContains(query) ||
                       (profile.displayName?.localizedCaseInsensitiveContains(query) ?? false) {

                        if !seenDIDs.contains(profile.did) {
                            results.append(profile)
                            seenDIDs.insert(profile.did)
                        }
                    }
                }
                print("📍 Found \(results.count) total matches (including followers) for '\(query)'")
            } catch {
                print("⚠️ Failed to search followers: \(error)")
            }

            guard searchText == query else { return }

            // 3. Search all users if we need more results
            if results.count < 20 {
                do {
                    let searchResults = try await client.searchUsers(query: query, limit: 20)

                    for profile in searchResults {
                        if !seenDIDs.contains(profile.did) {
                            results.append(profile)
                            seenDIDs.insert(profile.did)
                        }
                    }
                    print("📍 Found \(results.count) total matches (including general search) for '\(query)'")
                } catch {
                    print("⚠️ Failed to search users: \(error)")
                }
            }

            // Filter to only users who can receive messages
            let messageableResults = results.filter { profile in
                // Check if user follows them (needed to determine message availability)
                let currentUserFollowsThem = profile.viewer?.following != nil

                // Debug logging for chat availability
                if let chatSettings = profile.associated?.chat {
                    print("👤 \(profile.handle): allowIncoming = \(chatSettings.allowIncoming), following = \(currentUserFollowsThem)")
                } else {
                    print("👤 \(profile.handle): NO chat settings (defaulting to 'following'), following = \(currentUserFollowsThem)")
                }

                let canMessage = profile.canReceiveMessagesFrom(currentUserFollowsThem: currentUserFollowsThem)

                if !canMessage {
                    print("🚫 Filtered out \(profile.handle) - cannot receive messages")
                }

                return canMessage
            }

            // Limit to 20 results
            searchResults = Array(messageableResults.prefix(20))
            print("✅ Final search results: \(searchResults.count) messageable users for '\(query)' (filtered from \(results.count) total)")
        } catch {
            print("Search failed: \(error)")
        }

        isSearching = false
    }

    private func startConversation(with user: Profile) {
        isCreatingConversation = true
        errorMessage = nil

        Task {
            do {
                let response = try await client.getConvoForMembers(members: [user.did])
                selectedConversation = response.convo
                navigateToChat = true
            } catch {
                print("❌ Failed to create conversation with \(user.handle): \(error)")

                // Show user-friendly error message
                if let error = error as? ATProtoError {
                    switch error {
                    case .invalidResponse:
                        errorMessage = "\(user.displayName ?? user.handle) does not accept messages from you."
                    default:
                        errorMessage = "Unable to start conversation: \(error.localizedDescription)"
                    }
                } else {
                    errorMessage = "\(user.displayName ?? user.handle) does not accept messages from you."
                }

                showError = true
            }

            isCreatingConversation = false
        }
    }
}

struct UserSearchRow: View {
    let user: Profile

    var body: some View {
        HStack(spacing: 12) {
            AvatarImage(
                url: user.avatar.flatMap { URL(string: $0) },
                size: 52
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName ?? user.handle)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("@\(user.handle)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let description = user.description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

#Preview {
    NewConversationView()
        .environmentObject(AppTheme.shared)
}
