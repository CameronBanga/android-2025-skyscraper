//
//  PostDraft.swift
//  Skyscraper
//
//  Model for saving draft posts
//

import Foundation
import Combine

struct PostDraft: Codable, Identifiable {
    let id: UUID
    var text: String
    var imageData: [Data] // Store image data as Data arrays
    var imageAltTexts: [String]
    var createdAt: Date
    var updatedAt: Date
    var languageId: String
    var moderationSettings: PostModerationSettings

    init(
        id: UUID = UUID(),
        text: String,
        imageData: [Data] = [],
        imageAltTexts: [String] = [],
        languageId: String,
        moderationSettings: PostModerationSettings
    ) {
        self.id = id
        self.text = text
        self.imageData = imageData
        self.imageAltTexts = imageAltTexts
        self.createdAt = Date()
        self.updatedAt = Date()
        self.languageId = languageId
        self.moderationSettings = moderationSettings
    }

    var preview: String {
        if text.isEmpty {
            return "Empty draft"
        }
        return text.count > 100 ? String(text.prefix(100)) + "..." : text
    }

    var relativeTime: String {
        let interval = Date().timeIntervalSince(updatedAt)
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
            return "Just now"
        }
    }
}

// MARK: - Draft Manager
@MainActor
class DraftManager: ObservableObject {
    static let shared = DraftManager()

    @Published var drafts: [PostDraft] = []

    private let userDefaultsKey = "com.skyscraper.postDrafts"
    private let maxDrafts = 50

    private init() {
        loadDrafts()
    }

    func saveDraft(_ draft: PostDraft) {
        // Update existing draft or add new one
        if let index = drafts.firstIndex(where: { $0.id == draft.id }) {
            var updatedDraft = draft
            updatedDraft.updatedAt = Date()
            drafts[index] = updatedDraft
        } else {
            drafts.insert(draft, at: 0)
        }

        // Keep only the most recent drafts
        if drafts.count > maxDrafts {
            drafts = Array(drafts.prefix(maxDrafts))
        }

        persistDrafts()
    }

    func deleteDraft(_ draft: PostDraft) {
        drafts.removeAll { $0.id == draft.id }
        persistDrafts()
    }

    func getDraft(id: UUID) -> PostDraft? {
        drafts.first { $0.id == id }
    }

    private func loadDrafts() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode([PostDraft].self, from: data) else {
            drafts = []
            return
        }
        drafts = decoded
    }

    private func persistDrafts() {
        if let encoded = try? JSONEncoder().encode(drafts) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
}
