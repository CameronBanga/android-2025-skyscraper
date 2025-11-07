//
//  ChatView.swift
//  Skyscraper
//
//  Chat conversation view
//

import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @EnvironmentObject var theme: AppTheme
    @FocusState private var isTextFieldFocused: Bool
    @State private var keyboardHeight: CGFloat = 0

    init(conversation: ConvoView) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(conversation: conversation))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if viewModel.isLoading && viewModel.messages.isEmpty {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                                MessageBubble(
                                    message: message,
                                    conversation: viewModel.conversation,
                                    isFromCurrentUser: isFromCurrentUser(message),
                                    showAvatar: shouldShowAvatar(at: index)
                                )
                                .id(message.id)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    .padding(.bottom, 5)
                }
                .onChange(of: viewModel.messages.count) { oldCount, newCount in
                    if newCount > oldCount, let lastMessage = viewModel.messages.last {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                .onChange(of: isTextFieldFocused) { _, focused in
                    if focused, let lastMessage = viewModel.messages.last {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                .onAppear {
                    if let lastMessage = viewModel.messages.last {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Input bar
            HStack(spacing: 12) {
                TextField("Message", text: $viewModel.messageText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .focused($isTextFieldFocused)
                    .lineLimit(1...6)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    #if os(iOS)
                    .background(Color(uiColor: .secondarySystemBackground))
                    #else
                    .background(Color(nsColor: .controlBackgroundColor))
                    #endif
                    .cornerRadius(20)

                Button {
                    Task {
                        await viewModel.sendMessage()
                    }
                } label: {
                    if viewModel.isSending {
                        ProgressView()
                            .tint(.white)
                            .frame(width: 36, height: 36)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(
                                viewModel.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? Color.secondary
                                    : theme.accentColor
                            )
                    }
                }
                .disabled(viewModel.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            #if os(iOS)
            .background(Color(uiColor: .systemBackground))
            #else
            .background(Color(nsColor: .windowBackgroundColor))
            #endif
        }
        .navigationTitle(viewModel.conversation.displayName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            if viewModel.messages.isEmpty {
                await viewModel.loadMessages()
            }
            viewModel.startPolling()
        }
        .onAppear {
            isTextFieldFocused = true
        }
        .onDisappear {
            viewModel.stopPolling()
        }
    }

    private func isFromCurrentUser(_ message: MessageUnion) -> Bool {
        let currentUserDID = ATProtoClient.shared.session?.did ?? ""
        switch message {
        case .messageView(let view):
            return view.sender.did == currentUserDID
        case .deletedMessageView(let view):
            return view.sender.did == currentUserDID
        }
    }

    private func shouldShowAvatar(at index: Int) -> Bool {
        guard index < viewModel.messages.count else { return false }

        let currentMessage = viewModel.messages[index]
        let isFromUser = isFromCurrentUser(currentMessage)

        // Always show avatar for messages from others
        if !isFromUser {
            if index == viewModel.messages.count - 1 {
                return true
            }

            let nextMessage = viewModel.messages[index + 1]
            let nextIsFromUser = isFromCurrentUser(nextMessage)
            return nextIsFromUser
        }

        return false
    }
}

struct MessageBubble: View {
    let message: MessageUnion
    let conversation: ConvoView
    let isFromCurrentUser: Bool
    let showAvatar: Bool
    @EnvironmentObject var theme: AppTheme

    private func getMember(for did: String) -> ConvoMember? {
        conversation.members.first { $0.did == did }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isFromCurrentUser {
                Spacer(minLength: 60)
            }

            if !isFromCurrentUser {
                if showAvatar {
                    avatarView
                } else {
                    Color.clear
                        .frame(width: 32, height: 32)
                }
            }

            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                messageBubble

                timeText
            }
        }
        .frame(maxWidth: .infinity, alignment: isFromCurrentUser ? .trailing : .leading)
    }

    private var senderDID: String {
        switch message {
        case .messageView(let view):
            return view.sender.did
        case .deletedMessageView(let view):
            return view.sender.did
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        if let member = getMember(for: senderDID) {
            AvatarImage(
                url: member.avatar.flatMap { URL(string: $0) },
                size: 32
            )
        } else {
            AvatarImage(url: nil, size: 32)
        }
    }

    @ViewBuilder
    private var messageBubble: some View {
        switch message {
        case .messageView(let messageView):
            if let text = messageView.text, !text.isEmpty {
                Text(text)
                    .font(.body)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    #if os(iOS)
                    .background(isFromCurrentUser ? theme.accentColor : Color(uiColor: .secondarySystemBackground))
                    #else
                    .background(isFromCurrentUser ? theme.accentColor : Color(nsColor: .controlBackgroundColor))
                    #endif
                    .foregroundStyle(isFromCurrentUser ? .white : .primary)
                    .cornerRadius(18)
            }
        case .deletedMessageView:
            Text("Message deleted")
                .font(.body)
                .italic()
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                #if os(iOS)
                .background(Color(uiColor: .secondarySystemBackground))
                #else
                .background(Color(nsColor: .controlBackgroundColor))
                #endif
                .foregroundStyle(.secondary)
                .cornerRadius(18)
        }
    }

    private var timeText: some View {
        Text(relativeTime(from: message.sentAt))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
    }

    private func relativeTime(from dateString: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: dateString) else {
            return ""
        }

        let now = Date()
        let components = Calendar.current.dateComponents(
            [.day, .hour, .minute],
            from: date,
            to: now
        )

        if let day = components.day, day > 0 {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if let hour = components.hour, hour > 0 {
            return "\(hour)h ago"
        } else if let minute = components.minute, minute > 0 {
            return "\(minute)m ago"
        } else {
            return "now"
        }
    }
}

#Preview {
    NavigationStack {
        ChatView(conversation: ConvoView(
            id: "test",
            rev: "1",
            members: [],
            lastMessage: nil,
            muted: false,
            unreadCount: 0
        ))
    }
    .environmentObject(AppTheme.shared)
}
