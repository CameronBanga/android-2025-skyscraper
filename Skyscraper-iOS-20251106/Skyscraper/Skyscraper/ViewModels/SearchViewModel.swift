//
//  SearchViewModel.swift
//  Skyscraper
//
//  Manages user search
//

import Foundation
import Combine

@MainActor
class SearchViewModel: ObservableObject {
    @Published var users: [Profile] = []
    @Published var isSearching = false
    @Published var errorMessage: String?

    private let client = ATProtoClient.shared
    private var searchTask: Task<Void, Never>?

    func search(query: String) async {
        // Cancel previous search
        searchTask?.cancel()

        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            users = []
            return
        }

        searchTask = Task {
            // Debounce search
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms

            guard !Task.isCancelled else { return }

            isSearching = true
            errorMessage = nil

            do {
                let results = try await client.searchUsers(query: query)
                guard !Task.isCancelled else { return }
                users = results
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
            }

            isSearching = false
        }
    }
}
