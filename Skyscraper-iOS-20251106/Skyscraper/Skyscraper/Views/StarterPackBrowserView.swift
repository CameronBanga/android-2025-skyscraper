//
//  StarterPackBrowserView.swift
//  Skyscraper
//
//  Browse curated starter packs
//

import SwiftUI
import Combine

struct StarterPackBrowserView: View {
    @StateObject private var viewModel = StarterPackBrowserViewModel()
    @EnvironmentObject var theme: AppTheme
    @State private var searchText = ""
    @Environment(\.openURL) private var openURL

    var filteredPacks: [StarterPack] {
        if searchText.isEmpty {
            return viewModel.starterPacks
        } else {
            return viewModel.starterPacks.filter { pack in
                pack.record.name.localizedCaseInsensitiveContains(searchText) ||
                (pack.record.description?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                pack.creator.safeHandle.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading && viewModel.starterPacks.isEmpty {
                ProgressView("Loading starter packs...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = viewModel.errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text("Unable to load starter packs")
                        .font(.headline)
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Try Again") {
                        Task { await viewModel.loadStarterPacks() }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.starterPacks.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No starter packs available")
                        .font(.headline)
                    Text("Check back later for curated communities")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredPacks) { pack in
                        StarterPackRow(pack: pack, openURL: openURL)
                    }
                }
                .listStyle(.plain)
                .searchable(text: $searchText, prompt: "Search starter packs")
            }
        }
        .navigationTitle("Browse Starter Packs")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .refreshable {
            await viewModel.loadStarterPacks()
        }
        .task {
            if viewModel.starterPacks.isEmpty {
                await viewModel.loadStarterPacks()
            }
        }
    }
}

struct StarterPackRow: View {
    let pack: StarterPack
    let openURL: OpenURLAction
    @EnvironmentObject var theme: AppTheme

    var body: some View {
        NavigationLink(destination: StarterPackDetailView(starterPack: pack)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    // Creator avatar
                    AvatarImage(
                        url: pack.creator.avatar.flatMap { URL(string: $0) },
                        size: 50
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(pack.record.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)

                        Text("by @\(pack.creator.safeHandle)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        // Stats
                        HStack(spacing: 12) {
                            if let listItemCount = pack.listItemCount, listItemCount > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "person.2.fill")
                                        .font(.caption2)
                                    Text("\(listItemCount)")
                                        .font(.caption2)
                                }
                                .foregroundStyle(.secondary)
                            }

                            if let joinedCount = pack.joinedAllTimeCount, joinedCount > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.forward")
                                        .font(.caption2)
                                    Text("\(joinedCount) joined")
                                        .font(.caption2)
                                }
                                .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Spacer()
                }

                if let description = pack.record.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
            .padding(.vertical, 8)
        }
    }
}

@MainActor
class StarterPackBrowserViewModel: ObservableObject {
    @Published var starterPacks: [StarterPack] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let client = ATProtoClient.shared

    func loadStarterPacks() async {
        isLoading = true
        errorMessage = nil

        do {
            // Load config from JSON file
            guard let configItems = loadStarterPackConfig() else {
                starterPacks = []
                isLoading = false
                return
            }

            // Resolve handles to DIDs and build URIs
            var uris: [String] = []
            for item in configItems {
                if item.handle.starts(with: "did:") {
                    // Already a DID
                    uris.append("at://\(item.handle)/app.bsky.graph.starterpack/\(item.rkey)")
                } else {
                    // Need to resolve handle to DID
                    do {
                        let profile = try await client.getProfile(actor: item.handle)
                        uris.append("at://\(profile.did)/app.bsky.graph.starterpack/\(item.rkey)")
                    } catch {
                        print("Failed to resolve handle \(item.handle): \(error)")
                        // Skip this starter pack
                    }
                }
            }

            if uris.isEmpty {
                starterPacks = []
                isLoading = false
                return
            }

            // Fetch starter packs from API
            let response = try await client.getStarterPacks(uris: uris)

            // Preserve the original order from the API response
            starterPacks = response.starterPacks

            print("✅ Loaded \(starterPacks.count) starter packs")
        } catch {
            errorMessage = error.localizedDescription
            print("Failed to load starter packs: \(error)")
        }

        isLoading = false
    }

    private func loadStarterPackConfig() -> [StarterPackConfigItem]? {
        guard let url = Bundle.main.url(forResource: "StarterPacks", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONDecoder().decode(StarterPacksConfig.self, from: data) else {
            print("Failed to load StarterPacks.json")
            return nil
        }

        return json.starterPacks
    }
}

struct StarterPacksConfig: Codable {
    let starterPacks: [StarterPackConfigItem]
}

struct StarterPackConfigItem: Codable {
    let name: String
    let handle: String  // Can be either a handle (e.g., "user.bsky.social") or DID (e.g., "did:plc:...")
    let rkey: String    // The record key from the URL
    let category: String
}

#Preview {
    NavigationStack {
        StarterPackBrowserView()
    }
}
