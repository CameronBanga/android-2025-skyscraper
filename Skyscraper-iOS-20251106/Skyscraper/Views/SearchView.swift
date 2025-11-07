//
//  SearchView.swift
//  Skyscraper
//
//  Search for users and posts
//

import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @EnvironmentObject var theme: AppTheme
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            VStack {
                if viewModel.isSearching {
                    ProgressView()
                        .padding()
                } else if searchText.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)

                        Text("Search BlueSky")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Find people and posts")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                } else if let errorMessage = viewModel.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)

                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else if viewModel.users.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.slash")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)

                        Text("No users found")
                            .font(.headline)

                        Text("Try a different search term")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                } else {
                    List(viewModel.users) { user in
                        NavigationLink(destination: ProfileView(actor: user.handle)) {
                            HStack(spacing: 12) {
                                // Avatar with retry logic
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
                                            .lineLimit(2)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Search")
            .searchable(text: $searchText, prompt: "Search users")
            .onChange(of: searchText) { oldValue, newValue in
                Task {
                    await viewModel.search(query: newValue)
                }
            }
        }
        .tint(theme.accentColor)
    }
}

#Preview {
    SearchView()
}
