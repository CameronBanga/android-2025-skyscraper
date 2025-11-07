//
//  ChatListViewModel.swift
//  Skyscraper
//
//  Manages chat conversations list
//

import Foundation
import Combine

@MainActor
class ChatListViewModel: ObservableObject {
    @Published var conversations: [ConvoView] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let client = ATProtoClient.shared
    private var cursor: String?
    private var pollingTask: Task<Void, Never>?

    deinit {
        pollingTask?.cancel()
    }

    func startPolling() {
        // Cancel any existing polling task
        pollingTask?.cancel()

        pollingTask = Task {
            while !Task.isCancelled {
                // Wait 2.5 seconds
                try? await Task.sleep(nanoseconds: 2_500_000_000)

                guard !Task.isCancelled else { break }

                // Poll for updates
                await pollForUpdates()
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func loadConversations() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await client.listConvos(limit: 50)
            conversations = response.convos
            cursor = response.cursor
            print("✅ Loaded \(conversations.count) conversations")
        } catch {
            // Check if this is a cancellation error (Code -999)
            // This happens when the request is cancelled (app backgrounded, view dismissed, etc.)
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                // Don't show cancellation errors to the user - they're expected
                print("⚠️ Conversation load was cancelled (expected)")
            } else {
                // Use the error's localized description (which includes our detailed messages)
                errorMessage = error.localizedDescription
                print("❌ Failed to load conversations: \(error)")
            }
        }

        isLoading = false
    }

    func refreshConversations() async {
        cursor = nil
        await loadConversations()
    }

    func loadMoreIfNeeded(conversation: ConvoView) async {
        guard let lastConvo = conversations.last,
              lastConvo.id == conversation.id,
              let cursor = cursor,
              !isLoading else {
            return
        }

        do {
            let response = try await client.listConvos(limit: 50, cursor: cursor)
            conversations.append(contentsOf: response.convos)
            self.cursor = response.cursor
        } catch {
            print("❌ Failed to load more conversations: \(error)")
        }
    }

    private func pollForUpdates() async {
        guard !isLoading else {
            print("⏸️ Skipping poll - already loading")
            return
        }

        do {
            // Fetch the latest conversations
            let response = try await client.listConvos(limit: 50)

            print("🔄 Polling: Got \(response.convos.count) conversations")

            // Check if anything actually changed
            let hasChanges = response.convos != conversations

            // Simply replace with the fresh data from the API
            // This ensures we get updated lastMessage, unreadCount, etc.
            conversations = response.convos
            cursor = response.cursor

            if hasChanges {
                print("✅ Polled and updated conversations list - changes detected")
            } else {
                print("✅ Polled conversations list - no changes")
            }
        } catch {
            // Check if this is a cancellation error - don't log those
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                print("⚠️ Polling cancelled (expected)")
            } else {
                print("❌ Failed to poll for conversation updates: \(error)")
            }
        }
    }
}
