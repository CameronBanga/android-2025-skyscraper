//
//  DiscoverView.swift
//  Skyscraper
//
//  Discover starter packs and communities
//

import SwiftUI

struct DiscoverView: View {
    @StateObject private var viewModel = DiscoverViewModel()
    @Environment(\.openURL) private var openURL
    @EnvironmentObject var theme: AppTheme
    @State private var hashtagToSearch: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Find interesting people and communities to follow on BlueSky")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 8)

                    // Trending Topics Section
                    if !viewModel.trendingTopics.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Trending Topics")
                                .font(.headline)
                                .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(viewModel.trendingTopics) { topic in
                                        Button(action: {
                                            hashtagToSearch = topic.hashtag
                                        }) {
                                            TrendingTopicChip(topic: topic)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    } else if viewModel.isLoadingTopics {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Trending Topics")
                                .font(.headline)
                                .padding(.horizontal)

                            ProgressView()
                                .frame(maxWidth: .infinity)
                        }
                    }

                    // Getting Started Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Getting Started")
                            .font(.headline)
                            .padding(.horizontal)

                        VStack(spacing: 12) {
                            NavigationLink(destination: SearchView()) {
                                TipCard(
                                    icon: "magnifyingglass",
                                    title: "Search for Users",
                                    description: "Find people to follow on BlueSky"
                                )
                            }
                            .buttonStyle(.plain)

                            NavigationLink(destination: FeedBrowserView()) {
                                TipCard(
                                    icon: "antenna.radiowaves.left.and.right",
                                    title: "Browse Feeds",
                                    description: "Discover custom feeds curated by the community"
                                )
                            }
                            .buttonStyle(.plain)

                            NavigationLink(destination: StarterPackBrowserView()) {
                                TipCard(
                                    icon: "person.3.fill",
                                    title: "Browse Starter Packs",
                                    description: "Find curated communities and people to follow"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal)
                    }

                    // Suggested Users Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Suggested Users")
                            .font(.headline)
                            .padding(.horizontal)

                        if viewModel.isLoading && viewModel.suggestedUsers.isEmpty {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else if !viewModel.suggestedUsers.isEmpty {
                            VStack(spacing: 12) {
                                ForEach(viewModel.suggestedUsers) { user in
                                    NavigationLink(destination: ProfileView(actor: user.handle)) {
                                        SuggestedUserRow(user: user)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        } else {
                            Text("No suggestions available")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }

                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("Discover")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .navigationDestination(item: Binding(
                get: { hashtagToSearch.map { HashtagWrapper(tag: $0) } },
                set: { hashtagToSearch = $0?.tag }
            )) { wrapper in
                HashtagSearchView(hashtag: wrapper.tag)
            }
            .refreshable {
                await viewModel.loadSuggestions()
            }
        }
        .tint(theme.accentColor)
        .task {
            if viewModel.suggestedUsers.isEmpty {
                await viewModel.loadSuggestions()
            }
        }
    }
}

struct SuggestedUserRow: View {
    let user: Profile

    var body: some View {
        HStack(spacing: 12) {
            AvatarImage(
                url: user.avatar.flatMap { URL(string: $0) },
                size: 50
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
                        .lineLimit(5)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        #if os(iOS)
        .background(Color(uiColor: .secondarySystemBackground))
        #else
        .background(Color(nsColor: .controlBackgroundColor))
        #endif
        .cornerRadius(12)
    }
}

struct TipCard: View {
    let icon: String
    let title: String
    let description: String
    @EnvironmentObject var theme: AppTheme

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(theme.accentColor)
                .frame(width: 44, height: 44)
                .background(theme.accentColor.opacity(0.1))
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        #if os(iOS)
        .background(Color(uiColor: .secondarySystemBackground))
        #else
        .background(Color(nsColor: .controlBackgroundColor))
        #endif
        .cornerRadius(12)
    }
}

struct TrendingTopicChip: View {
    let topic: TrendingTopic
    @EnvironmentObject var theme: AppTheme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.caption)
                .foregroundStyle(theme.accentColor)

            Text(topic.topic)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(theme.accentColor.opacity(0.1))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(theme.accentColor.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    DiscoverView()
}
