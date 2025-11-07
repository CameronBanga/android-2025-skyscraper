//
//  ChatViewModel.swift
//  Skyscraper
//
//  Manages individual chat conversation
//

import Foundation
import Combine

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [MessageUnion] = []
    @Published var messageText = ""
    @Published var isLoading = false
    @Published var isSending = false
    @Published var errorMessage: String?

    let conversation: ConvoView
    private let client = ATProtoClient.shared
    private var cursor: String?
    private var pollingTask: Task<Void, Never>?

    init(conversation: ConvoView) {
        self.conversation = conversation
    }

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

                // Poll for new messages
                await pollForNewMessages()
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func loadMessages() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await client.getMessages(convoId: conversation.id, limit: 50)
            messages = response.messages.reversed() // Reverse to show oldest first
            cursor = response.cursor
            print("✅ Loaded \(messages.count) messages")

            // Mark as read
            try? await client.updateRead(convoId: conversation.id)
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Failed to load messages: \(error)")
        }

        isLoading = false
    }

    func sendMessage() async {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let textToSend = messageText
        messageText = "" // Clear immediately for better UX

        isSending = true

        do {
            let messageInput = MessageInput(text: textToSend)
            let response = try await client.sendMessage(convoId: conversation.id, message: messageInput)

            // Add the new message to the list
            let newMessage = MessageView(
                id: response.id,
                rev: response.rev,
                text: response.text,
                facets: response.facets,
                embed: response.embed,
                sender: response.sender,
                sentAt: response.sentAt
            )
            messages.append(.messageView(newMessage))

            print("✅ Message sent successfully")
        } catch {
            print("❌ Failed to send message: \(error)")
            // Restore the text so user can try again
            messageText = textToSend
            errorMessage = "Failed to send message. Please try again."
        }

        isSending = false
    }

    func loadMoreMessages() async {
        guard let cursor = cursor, !isLoading else {
            return
        }

        do {
            let response = try await client.getMessages(convoId: conversation.id, limit: 50, cursor: cursor)
            messages.insert(contentsOf: response.messages.reversed(), at: 0)
            self.cursor = response.cursor
        } catch {
            print("❌ Failed to load more messages: \(error)")
        }
    }

    private func pollForNewMessages() async {
        guard !isLoading && !isSending else {
            return
        }

        do {
            // Get the latest messages without cursor to fetch newest ones
            let response = try await client.getMessages(convoId: conversation.id, limit: 50)
            let newMessages = response.messages.reversed()

            // Find messages we don't have yet
            let existingIds = Set(messages.map { $0.id })
            let messagesToAdd = newMessages.filter { !existingIds.contains($0.id) }

            if !messagesToAdd.isEmpty {
                messages.append(contentsOf: messagesToAdd)
                print("✅ Polled and found \(messagesToAdd.count) new message(s)")

                // Mark as read
                try? await client.updateRead(convoId: conversation.id)
            }
        } catch {
            print("❌ Failed to poll for new messages: \(error)")
        }
    }
}
