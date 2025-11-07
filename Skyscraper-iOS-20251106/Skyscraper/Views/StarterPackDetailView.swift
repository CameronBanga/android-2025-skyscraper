//
//  StarterPackDetailView.swift
//  Skyscraper
//
//  View individual starter pack with users to follow
//

import SwiftUI
import Combine

struct StarterPackDetailView: View {
    let starterPack: StarterPack
    @StateObject private var viewModel = StarterPackDetailViewModel()
    @EnvironmentObject var theme: AppTheme
    @State private var searchText = ""

    var filteredUsers: [ListItemView] {
        if searchText.isEmpty {
            return viewModel.users
        } else {
            return viewModel.users.filter { item in
                item.subject.displayName?.localizedCaseInsensitiveContains(searchText) ?? false ||
                item.subject.safeHandle.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading && viewModel.users.isEmpty {
                ProgressView("Loading users...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = viewModel.errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text("Unable to load users")
                        .font(.headline)
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Try Again") {
                        Task { await viewModel.loadUsers(listURI: starterPack.record.list) }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    // Header section
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                AvatarImage(
                                    url: starterPack.creator.avatar.flatMap { URL(string: $0) },
                                    size: 60
                                )

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(starterPack.record.name)
                                        .font(.title3)
                                        .fontWeight(.bold)

                                    Text("by @\(starterPack.creator.safeHandle)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            if let description = starterPack.record.description, !description.isEmpty {
                                Text(description)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 16) {
                                if let count = starterPack.listItemCount {
                                    HStack(spacing: 4) {
                                        Image(systemName: "person.2.fill")
                                        Text("\(count) people")
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }

                                if let joined = starterPack.joinedAllTimeCount {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.up.forward")
                                        Text("\(joined) joined")
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    // Users section
                    Section {
                        ForEach(filteredUsers) { item in
                            NavigationLink(destination: ProfileView(actor: item.subject.safeHandle)) {
                                UserRowWithFollow(
                                    user: item.subject,
                                    viewModel: viewModel
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        HStack {
                            Text("People in this starter pack")

                            Spacer()

                            Button(action: {
                                Task {
                                    await viewModel.followAll()
                                }
                            }) {
                                if viewModel.isFollowingAll {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Text("Follow All")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(theme.accentColor)
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.isFollowingAll)
                        }
                    }
                }
                #if os(iOS)
                .listStyle(.insetGrouped)
                #else
                .listStyle(.plain)
                #endif
                .searchable(text: $searchText, prompt: "Search people")
            }
        }
        .navigationTitle("Starter Pack")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            if viewModel.users.isEmpty {
                await viewModel.loadUsers(listURI: starterPack.record.list)
            }
        }
    }
}

struct UserRowWithFollow: View {
    let user: Author
    @ObservedObject var viewModel: StarterPackDetailViewModel
    @EnvironmentObject var theme: AppTheme

    var isFollowing: Bool {
        user.viewer?.following != nil
    }

    var isTogglingFollow: Bool {
        viewModel.togglingFollowDID == user.did
    }

    var body: some View {
        HStack(spacing: 12) {
            AvatarImage(
                url: user.avatar.flatMap { URL(string: $0) },
                size: 50
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName ?? user.safeHandle)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("@\(user.safeHandle)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let description = user.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Button(action: {
                Task {
                    await viewModel.toggleFollow(user: user)
                }
            }) {
                if isTogglingFollow {
                    ProgressView()
                        .frame(width: 80)
                } else {
                    Text(isFollowing ? "Following" : "Follow")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(isFollowing ? theme.accentColor : .white)
                        .frame(width: 80)
                        .padding(.vertical, 6)
                        .background(isFollowing ? Color.clear : theme.accentColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(theme.accentColor, lineWidth: isFollowing ? 1 : 0)
                        )
                        .cornerRadius(8)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

@MainActor
class StarterPackDetailViewModel: ObservableObject {
    @Published var users: [ListItemView] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var togglingFollowDID: String?
    @Published var isFollowingAll = false

    private let client = ATProtoClient.shared

    func loadUsers(listURI: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await client.getList(list: listURI, limit: 100)
            users = response.items

            print("✅ Loaded \(users.count) users from starter pack")
        } catch {
            errorMessage = error.localizedDescription
            print("Failed to load users: \(error)")
        }

        isLoading = false
    }

    func toggleFollow(user: Author) async {
        togglingFollowDID = user.did

        do {
            if user.viewer?.following != nil {
                // Unfollow
                try await client.unfollowUser(followUri: user.viewer!.following!)

                // Update local state
                if let index = users.firstIndex(where: { $0.subject.did == user.did }) {
                    var updatedUser = users[index].subject
                    updatedUser.viewer?.following = nil
                    users[index] = ListItemView(uri: users[index].uri, subject: updatedUser)
                }

                Analytics.logEvent("user_interaction", parameters: [
                    "action": "unfollow",
                    "source": "starter_pack",
                    "user_did": user.did
                ])
                print("📊 Analytics: Logged user_interaction (unfollow from starter pack)")
            } else {
                // Follow
                let followURI = try await client.followUser(did: user.did)

                // Update local state
                if let index = users.firstIndex(where: { $0.subject.did == user.did }) {
                    var updatedUser = users[index].subject
                    if updatedUser.viewer == nil {
                        updatedUser.viewer = ProfileViewer(muted: false, blockedBy: false, following: followURI, followedBy: nil)
                    } else {
                        updatedUser.viewer?.following = followURI
                    }
                    users[index] = ListItemView(uri: users[index].uri, subject: updatedUser)
                }

                Analytics.logEvent("user_interaction", parameters: [
                    "action": "follow",
                    "source": "starter_pack",
                    "user_did": user.did
                ])
                print("📊 Analytics: Logged user_interaction (follow from starter pack)")
            }
        } catch {
            print("Failed to toggle follow: \(error)")
        }

        togglingFollowDID = nil
    }

    func followAll() async {
        isFollowingAll = true

        // Get all users who aren't already followed
        let usersToFollow = users.filter { $0.subject.viewer?.following == nil }

        print("📍 Following \(usersToFollow.count) users from starter pack")

        for item in usersToFollow {
            do {
                // Follow the user
                let followURI = try await client.followUser(did: item.subject.did)

                // Update local state
                if let index = users.firstIndex(where: { $0.subject.did == item.subject.did }) {
                    var updatedUser = users[index].subject
                    if updatedUser.viewer == nil {
                        updatedUser.viewer = ProfileViewer(muted: false, blockedBy: false, following: followURI, followedBy: nil)
                    } else {
                        updatedUser.viewer?.following = followURI
                    }
                    users[index] = ListItemView(uri: users[index].uri, subject: updatedUser)
                }

                print("✅ Followed @\(item.subject.safeHandle)")
            } catch {
                print("Failed to follow @\(item.subject.safeHandle): \(error)")
            }

            // Small delay to avoid rate limiting
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }

        Analytics.logEvent("user_interaction", parameters: [
            "action": "follow_all",
            "source": "starter_pack",
            "count": usersToFollow.count
        ])
        print("📊 Analytics: Logged follow_all (\(usersToFollow.count) users)")

        isFollowingAll = false
    }
}

#Preview {
    NavigationStack {
        StarterPackDetailView(starterPack: StarterPack(
            uri: "at://did:plc:test/app.bsky.graph.starterpack/test",
            cid: "test",
            record: StarterPackRecord(
                name: "Test Starter Pack",
                description: "A test starter pack",
                descriptionFacets: nil,
                list: "at://did:plc:test/app.bsky.graph.list/test",
                feeds: nil,
                createdAt: ""
            ),
            creator: Author(
                did: "did:plc:test",
                handle: "test.bsky.social",
                displayName: "Test User",
                description: nil,
                avatar: nil,
                associated: nil,
                viewer: nil,
                labels: nil,
                createdAt: nil
            ),
            listItemCount: 10,
            joinedWeekCount: 5,
            joinedAllTimeCount: 100,
            labels: nil,
            indexedAt: nil
        ))
    }
}
