//
//  CurrentUserProfileView.swift
//  Skyscraper
//
//  Shows the logged-in user's profile
//

import SwiftUI

struct CurrentUserProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var profile: Profile?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let client = ATProtoClient.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    ProgressView()
                        .padding()
                } else if let profile = profile {
                    VStack(spacing: 0) {
                        // Banner
                        if let bannerURL = profile.banner, let url = URL(string: bannerURL) {
                            RetryableAsyncImage(
                                url: url,
                                maxRetries: 3,
                                retryDelay: 1.0,
                                content: { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                },
                                placeholder: {
                                    Rectangle()
                                        .fill(LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ))
                                }
                            )
                            .frame(height: 150)
                            .clipped()
                        } else {
                            Rectangle()
                                .fill(LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(height: 150)
                        }

                        VStack(alignment: .leading, spacing: 16) {
                            // Avatar and edit button
                            HStack(alignment: .top) {
                                AvatarImage(
                                    url: profile.avatar.flatMap { URL(string: $0) },
                                    size: 80
                                )
                                .overlay(
                                    Circle()
                                        #if os(iOS)
                                        .stroke(Color(uiColor: .systemBackground), lineWidth: 4)
                                        #else
                                        .stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 4)
                                        #endif
                                )
                                .offset(y: -40)

                                Spacer()

                                Button {
                                    authViewModel.logout()
                                } label: {
                                    Text("Logout")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(Color.red.opacity(0.1))
                                        .foregroundStyle(.red)
                                        .cornerRadius(20)
                                }
                            }
                            .padding(.horizontal, 24)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(profile.displayName ?? profile.handle)
                                    .font(.title2)
                                    .fontWeight(.bold)

                                Text("@\(profile.handle)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, -30)

                            if let description = profile.description {
                                Text(description)
                                    .font(.body)
                                    .padding(.horizontal, 24)
                            }

                            // Stats
                            HStack(spacing: 24) {
                                StatView(
                                    count: profile.postsCount ?? 0,
                                    label: "Posts"
                                )

                                StatView(
                                    count: profile.followersCount ?? 0,
                                    label: "Followers"
                                )

                                StatView(
                                    count: profile.followsCount ?? 0,
                                    label: "Following"
                                )
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 8)
                        }
                    }
                } else if let errorMessage = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)

                        Text(errorMessage)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Button("Try Again") {
                            Task {
                                await loadProfile()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                }
            }
            .navigationTitle("Profile")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .task {
            await loadProfile()
        }
    }

    private func loadProfile() async {
        guard let session = client.session else {
            errorMessage = "Not logged in"
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            profile = try await client.getProfile(actor: session.did)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

#Preview {
    CurrentUserProfileView()
}
