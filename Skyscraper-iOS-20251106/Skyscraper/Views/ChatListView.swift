//
//  ChatListView.swift
//  Skyscraper
//
//  Chat conversations list
//

import SwiftUI

struct ChatListView: View {
    @StateObject private var viewModel = ChatListViewModel()
    @EnvironmentObject var theme: AppTheme
    @State private var showingNewConversation = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.conversations.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = viewModel.errorMessage {
                    errorView(message: errorMessage)
                } else if viewModel.conversations.isEmpty {
                    emptyStateView
                } else {
                    conversationsList
                }
            }
            .navigationTitle("Chat")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingNewConversation = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.body)
                            .foregroundStyle(theme.accentColor)
                    }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button {
                        showingNewConversation = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.body)
                            .foregroundStyle(theme.accentColor)
                    }
                }
                #endif
            }
            .refreshable {
                await viewModel.refreshConversations()
            }
            .sheet(isPresented: $showingNewConversation) {
                NewConversationView()
            }
            .task {
                if viewModel.conversations.isEmpty {
                    await viewModel.loadConversations()
                }
                viewModel.startPolling()
            }
            .onDisappear {
                viewModel.stopPolling()
            }
        }
    }

    private var conversationsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.conversations) { conversation in
                    NavigationLink(destination: ChatView(conversation: conversation)) {
                        ConversationRow(conversation: conversation)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        Task {
                            await viewModel.loadMoreIfNeeded(conversation: conversation)
                        }
                    }

                    Divider()
                        .padding(.leading, 76)
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "message")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No conversations yet")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Start a new conversation to get started")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showingNewConversation = true
            } label: {
                HStack {
                    Image(systemName: "square.and.pencil")
                    Text("New Conversation")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(theme.accentColor)
                .cornerRadius(20)
            }
            .padding(.top, 8)
        }
        .padding()
    }

    private func errorView(message: String) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: message.contains("Not Enabled") ? "lock.circle.fill" : "exclamationmark.triangle")
                    .font(.system(size: 60))
                    .foregroundStyle(message.contains("Not Enabled") ? .orange : .secondary)
                    .padding(.top, 40)

                VStack(spacing: 12) {
                    // Parse title if present (text before first newline)
                    if let titleEnd = message.firstIndex(of: "\n") {
                        let title = String(message[..<titleEnd])
                        let body = String(message[message.index(after: titleEnd)...])

                        Text(title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)

                        Text(body)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(message)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 24)

                if !message.contains("Not Enabled") {
                    Button("Try Again") {
                        Task {
                            await viewModel.loadConversations()
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(theme.accentColor)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct ConversationRow: View {
    let conversation: ConvoView
    @EnvironmentObject var theme: AppTheme

    private func relativeTime(from dateString: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: dateString) else {
            return ""
        }

        let now = Date()
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date,
            to: now
        )

        if let year = components.year, year > 0 {
            return "\(year)y"
        } else if let month = components.month, month > 0 {
            return "\(month)mo"
        } else if let day = components.day, day > 0 {
            return "\(day)d"
        } else if let hour = components.hour, hour > 0 {
            return "\(hour)h"
        } else if let minute = components.minute, minute > 0 {
            return "\(minute)m"
        } else {
            return "now"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            AvatarImage(
                url: conversation.avatarURL,
                size: 52
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    Spacer()

                    if let lastMessage = conversation.lastMessage {
                        Text(relativeTime(from: lastMessage.sentAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let handle = conversation.displayHandle {
                    Text(handle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let lastMessage = conversation.lastMessage {
                    HStack {
                        switch lastMessage {
                        case .messageView(let message):
                            Text(message.text ?? "")
                                .font(.subheadline)
                                .foregroundStyle(conversation.unreadCount > 0 ? .primary : .secondary)
                                .lineLimit(2)
                        case .deletedMessageView:
                            Text("Message deleted")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .italic()
                        }

                        Spacer()

                        if conversation.unreadCount > 0 {
                            ZStack {
                                Circle()
                                    .fill(theme.accentColor)
                                    .frame(width: 20, height: 20)

                                Text("\(min(conversation.unreadCount, 99))")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(conversation.muted ? Color.secondary.opacity(0.05) : Color.clear)
    }
}

#Preview {
    ChatListView()
        .environmentObject(AppTheme.shared)
}
