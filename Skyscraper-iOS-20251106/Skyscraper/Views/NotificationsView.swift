//
//  NotificationsView.swift
//  Skyscraper
//
//  Notifications and replies view
//

import SwiftUI
import Combine

struct NotificationsView: View {
    @StateObject private var viewModel = NotificationsViewModel()
    @EnvironmentObject var theme: AppTheme
    @State private var urlToOpen: URL?
    @State private var profileToShow: String?
    @State private var postToShow: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    if viewModel.isLoading && viewModel.notifications.isEmpty {
                        ProgressView()
                            .padding()
                    } else if let errorMessage = viewModel.errorMessage, viewModel.notifications.isEmpty {
                        errorView(message: errorMessage)
                    } else if viewModel.notifications.isEmpty {
                        emptyView
                    } else {
                        ForEach(viewModel.notifications) { notification in
                            NotificationCell(
                                notification: notification,
                                profileToShow: $profileToShow,
                                postToShow: $postToShow
                            )
                            Divider()
                        }

                        if viewModel.cursor != nil {
                            ProgressView()
                                .padding()
                                .onAppear {
                                    Task { await viewModel.loadMore() }
                                }
                        }
                    }
                }
            }
            .navigationTitle("Activity")
            .disableScrollsToTop()  // Only timeline should respond to status bar tap
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Mark as Read") {
                        Task {
                            await viewModel.markAllAsRead()
                        }
                    }
                    .disabled(viewModel.notifications.allSatisfy { $0.isRead })
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button("Mark as Read") {
                        Task {
                            await viewModel.markAllAsRead()
                        }
                    }
                    .disabled(viewModel.notifications.allSatisfy { $0.isRead })
                }
                #endif
            }
            .task {
                await viewModel.loadNotifications()
            }
            .refreshable {
                await viewModel.refresh()
            }
            .navigationDestination(item: Binding(
                get: { profileToShow.map { ProfileWrapper(actor: $0) } },
                set: { profileToShow = $0?.actor }
            )) { wrapper in
                ProfileView(actor: wrapper.actor)
            }
            .navigationDestination(item: Binding(
                get: { postToShow.map { PostURIWrapper(uri: $0) } },
                set: { postToShow = $0?.uri }
            )) { wrapper in
                PostDetailView(postURI: wrapper.uri)
            }
        }
        .tint(theme.accentColor)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("Unable to load notifications")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task { await viewModel.loadNotifications() }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No notifications yet")
                .font(.headline)
            Text("You'll see replies, likes, and follows here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Notification Cell
struct NotificationCell: View {
    let notification: Notification
    @Binding var profileToShow: String?
    @Binding var postToShow: String?
    @EnvironmentObject var theme: AppTheme

    private func relativeTime(from dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let date = formatter.date(from: dateString) ?? {
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: dateString)
        }() else {
            return ""
        }

        let now = Date()
        let interval = now.timeIntervalSince(date)

        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)

        if days > 0 {
            return "\(days)d ago"
        } else if hours > 0 {
            return "\(hours)h ago"
        } else if minutes > 0 {
            return "\(minutes)m ago"
        } else {
            return "now"
        }
    }

    private var notificationIcon: String {
        switch notification.reason {
        case "like":
            return "heart.fill"
        case "repost":
            return "arrow.2.squarepath"
        case "follow":
            return "person.fill.badge.plus"
        case "mention":
            return "at"
        case "reply":
            return "bubble.left.fill"
        case "quote":
            return "quote.bubble.fill"
        default:
            return "bell.fill"
        }
    }

    private var notificationColor: Color {
        switch notification.reason {
        case "like":
            return .pink
        case "repost":
            return .green
        case "follow":
            return .blue
        case "mention", "reply":
            return .orange
        case "quote":
            return .purple
        default:
            return .gray
        }
    }

    private var notificationText: String {
        switch notification.reason {
        case "like":
            return "liked your post"
        case "repost":
            return "reposted your post"
        case "follow":
            return "followed you"
        case "mention":
            return "mentioned you"
        case "reply":
            return "replied to your post"
        case "quote":
            return "quoted your post"
        default:
            return "notification"
        }
    }

    var body: some View {
        Button(action: {
            if notification.reason == "follow" {
                profileToShow = notification.author.safeHandle
            } else {
                // For likes, reposts, quotes: use reasonSubject (the post that was liked/reposted/quoted)
                // For replies, mentions: use uri (the reply/mention post itself)
                postToShow = notification.reasonSubject ?? notification.uri
            }
        }) {
            HStack(alignment: .top, spacing: 12) {
                // Avatar
                Button(action: {
                    profileToShow = notification.author.safeHandle
                }) {
                    AvatarImage(
                        url: notification.author.avatar.flatMap { URL(string: $0) },
                        size: 48
                    )
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: notificationIcon)
                            .font(.system(size: 12))
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(notificationColor)
                            .clipShape(Circle())
                            .offset(x: 4, y: 4)  // Offset more to lower right
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    // Author name and timestamp
                    HStack {
                        Text((notification.author.displayName?.isEmpty == false) ? notification.author.displayName! : notification.author.shortHandle)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                        Text(relativeTime(from: notification.indexedAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Handle
                    Text("@\(notification.author.safeHandle)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Action text on its own line
                    Text(notificationText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    // Show post text if available
                    if let record = notification.record, !record.text.isEmpty {
                        Text(record.text)
                            .font(.body)
                            .lineLimit(3)
                            .padding(.top, 4)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(notification.isRead ? Color.clear : theme.accentColor.opacity(0.15))
            .contentShape(Rectangle())  // Make entire cell tappable including whitespace
        }
        .buttonStyle(.plain)
    }
}

// Helper to make URI identifiable for navigation
struct PostURIWrapper: Identifiable, Hashable {
    let id = UUID()
    let uri: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(uri)
    }

    static func == (lhs: PostURIWrapper, rhs: PostURIWrapper) -> Bool {
        lhs.uri == rhs.uri
    }
}

// MARK: - ViewModel
@MainActor
class NotificationsViewModel: ObservableObject {
    @Published var notifications: [Notification] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var cursor: String?
    @Published var unreadCount: Int = 0

    private let client = ATProtoClient.shared

    func loadNotifications() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await client.getNotifications(limit: 50)
            notifications = response.notifications
            cursor = response.cursor
            updateUnreadCount()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func updateUnreadCount() {
        unreadCount = notifications.filter { !$0.isRead }.count
    }

    func refresh() async {
        cursor = nil
        await loadNotifications()
    }

    func loadMore() async {
        guard let cursor = cursor, !isLoading else { return }

        isLoading = true

        do {
            let response = try await client.getNotifications(cursor: cursor, limit: 50)
            notifications.append(contentsOf: response.notifications)
            self.cursor = response.cursor
            updateUnreadCount()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func markAllAsRead() async {
        do {
            try await client.updateSeenNotifications()
            // Refresh notifications from server to get updated isRead status
            await loadNotifications()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
