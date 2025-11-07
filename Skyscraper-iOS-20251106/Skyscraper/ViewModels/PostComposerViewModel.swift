//
//  PostComposerViewModel.swift
//  Skyscraper
//
//  Handles post composition and submission
//

import Foundation
import SwiftUI
import Combine
import PhotosUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
class PostComposerViewModel: ObservableObject {
    @Published var text = "" {
        didSet {
            detectMention()
            detectHashtag()
        }
    }
    @Published var isPosting = false
    @Published var errorMessage: String?
    @Published var selectedPhotoItems: [PhotosPickerItem] = []
    @Published var selectedImages: [PlatformImage] = []
    @Published var imageAltTexts: [String] = [] // Alt text for each image
    @Published var mentionSuggestions: [Profile] = []
    @Published var isSearchingMentions = false
    @Published var currentMentionQuery: String?
    @Published var hashtagSuggestions: [String] = []
    @Published var isSearchingHashtags = false
    @Published var currentHashtagQuery: String?
    @Published var cursorPosition: Int = 0
    @Published var selectedLanguage: Language
    @Published var moderationSettings: PostModerationSettings

    private let client = ATProtoClient.shared
    private let replyTo: ReplyRef?
    private var mentionSearchTask: Task<Void, Never>?
    private var hashtagSearchTask: Task<Void, Never>?
    private var currentDraftId: UUID?

    var characterCount: Int {
        text.count
    }

    var canPost: Bool {
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasMedia = !selectedImages.isEmpty
        let withinLimit = text.count <= 300
        return (hasText || hasMedia) && withinLimit
    }

    var canSaveDraft: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !selectedImages.isEmpty
    }

    init(replyTo: ReplyRef? = nil, draft: PostDraft? = nil) {
        self.replyTo = replyTo
        self.selectedLanguage = LanguagePreferences.shared.preferredLanguage
        self.moderationSettings = .default

        // Load draft if provided
        if let draft = draft {
            self.currentDraftId = draft.id
            self.text = draft.text
            self.imageAltTexts = draft.imageAltTexts
            self.selectedLanguage = Language.allLanguages.first { $0.id == draft.languageId } ?? LanguagePreferences.shared.preferredLanguage
            self.moderationSettings = draft.moderationSettings

            // Convert image data back to PlatformImages
            self.selectedImages = draft.imageData.compactMap { PlatformImage(data: $0) }
        }
    }

    func loadSelectedPhotos() async {
        selectedImages.removeAll()
        imageAltTexts.removeAll()

        for item in selectedPhotoItems {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = PlatformImage(data: data) {
                selectedImages.append(image)
                imageAltTexts.append("") // Initialize with empty alt text
            }
        }
    }

    func removeImage(at index: Int) {
        guard index < selectedImages.count else { return }
        selectedImages.remove(at: index)
        selectedPhotoItems.remove(at: index)
        if index < imageAltTexts.count {
            imageAltTexts.remove(at: index)
        }
    }

    func updateAltText(at index: Int, text: String) {
        guard index < imageAltTexts.count else { return }
        imageAltTexts[index] = text
    }

    // MARK: - Mention Autocomplete

    func detectMention() {
        // Cancel any ongoing search
        mentionSearchTask?.cancel()

        // Find the current word being typed
        let cursorIndex = min(cursorPosition, text.count)
        let textBeforeCursor = String(text.prefix(cursorIndex))

        // Find the last @ symbol before cursor
        if let lastAtIndex = textBeforeCursor.lastIndex(of: "@") {
            // Get text from @ to cursor
            let mentionText = String(textBeforeCursor.suffix(from: lastAtIndex).dropFirst()) // Remove @

            // Check if there's a space (which would end the mention)
            if !mentionText.contains(" ") && !mentionText.isEmpty {
                currentMentionQuery = mentionText
                searchMentions(query: mentionText)
            } else if mentionText.isEmpty {
                // User just typed @, show popular suggestions
                currentMentionQuery = ""
                searchMentions(query: "")
            } else {
                // Space found, clear suggestions
                clearMentionSuggestions()
            }
        } else {
            // No @ found, clear suggestions
            clearMentionSuggestions()
        }
    }

    private func searchMentions(query: String) {
        // Cancel previous search
        mentionSearchTask?.cancel()

        isSearchingMentions = true

        mentionSearchTask = Task {
            do {
                // Add a small delay to avoid too many API calls
                try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

                guard !Task.isCancelled else { return }

                var results: [Profile] = []
                var seenDIDs = Set<String>()

                // Get current user's DID
                guard let currentUserDID = client.session?.did else {
                    isSearchingMentions = false
                    return
                }

                // 1. Search follows (people you follow)
                do {
                    let follows = try await client.getFollows(actor: currentUserDID, limit: 50)
                    guard !Task.isCancelled else { return }

                    for profile in follows {
                        // Filter by query
                        if query.isEmpty ||
                           profile.handle.localizedCaseInsensitiveContains(query) ||
                           (profile.displayName?.localizedCaseInsensitiveContains(query) ?? false) {

                            if !seenDIDs.contains(profile.did) {
                                results.append(profile)
                                seenDIDs.insert(profile.did)
                            }
                        }
                    }
                    print("📍 Found \(results.count) matches in follows for '\(query)'")
                } catch {
                    print("⚠️ Failed to search follows: \(error)")
                }

                guard !Task.isCancelled else { return }

                // 2. Search followers (people who follow you)
                do {
                    let followers = try await client.getFollowers(actor: currentUserDID, limit: 50)
                    guard !Task.isCancelled else { return }

                    for profile in followers {
                        // Filter by query
                        if query.isEmpty ||
                           profile.handle.localizedCaseInsensitiveContains(query) ||
                           (profile.displayName?.localizedCaseInsensitiveContains(query) ?? false) {

                            if !seenDIDs.contains(profile.did) {
                                results.append(profile)
                                seenDIDs.insert(profile.did)
                            }
                        }
                    }
                    print("📍 Found \(results.count) total matches (including followers) for '\(query)'")
                } catch {
                    print("⚠️ Failed to search followers: \(error)")
                }

                guard !Task.isCancelled else { return }

                // 3. Search all users if we need more results
                if results.count < 10 {
                    do {
                        let searchResults = try await client.searchUsers(query: query, limit: 10)
                        guard !Task.isCancelled else { return }

                        for profile in searchResults {
                            if !seenDIDs.contains(profile.did) {
                                results.append(profile)
                                seenDIDs.insert(profile.did)
                            }
                        }
                        print("📍 Found \(results.count) total matches (including general search) for '\(query)'")
                    } catch {
                        print("⚠️ Failed to search users: \(error)")
                    }
                }

                guard !Task.isCancelled else { return }

                // Limit to 10 results
                mentionSuggestions = Array(results.prefix(10))
                isSearchingMentions = false
                print("✅ Final mention suggestions: \(mentionSuggestions.count) for '\(query)'")
            } catch {
                if !Task.isCancelled {
                    print("Failed to search mentions: \(error)")
                    isSearchingMentions = false
                }
            }
        }
    }

    func insertMention(_ profile: Profile) {
        let cursorIndex = min(cursorPosition, text.count)
        let textBeforeCursor = String(text.prefix(cursorIndex))

        // Find the last @ symbol
        if let lastAtIndex = textBeforeCursor.lastIndex(of: "@") {
            let beforeAt = String(text.prefix(upTo: lastAtIndex))
            let afterCursor = String(text.suffix(from: text.index(text.startIndex, offsetBy: cursorIndex)))

            // Insert the mention
            let mention = "@\(profile.handle) "
            text = beforeAt + mention + afterCursor

            // Update cursor position to after the inserted mention
            cursorPosition = beforeAt.count + mention.count

            // Clear suggestions
            clearMentionSuggestions()
        }
    }

    func clearMentionSuggestions() {
        currentMentionQuery = nil
        mentionSuggestions = []
        isSearchingMentions = false
        mentionSearchTask?.cancel()
    }

    // MARK: - Hashtag Autocomplete

    func detectHashtag() {
        // Cancel any ongoing search
        hashtagSearchTask?.cancel()

        // Find the current word being typed
        let cursorIndex = min(cursorPosition, text.count)
        let textBeforeCursor = String(text.prefix(cursorIndex))

        // Find the last # symbol before cursor
        if let lastHashIndex = textBeforeCursor.lastIndex(of: "#") {
            // Get text from # to cursor
            let hashtagText = String(textBeforeCursor.suffix(from: lastHashIndex).dropFirst()) // Remove #

            // Check if there's a space (which would end the hashtag)
            if !hashtagText.contains(" ") && !hashtagText.isEmpty {
                currentHashtagQuery = hashtagText
                searchHashtags(query: hashtagText)
            } else if hashtagText.isEmpty {
                // User just typed #, show popular hashtags
                currentHashtagQuery = ""
                searchHashtags(query: "")
            } else {
                // Space found, clear suggestions
                clearHashtagSuggestions()
            }
        } else {
            // No # found, clear suggestions
            clearHashtagSuggestions()
        }
    }

    private func searchHashtags(query: String) {
        // Cancel previous search
        hashtagSearchTask?.cancel()

        isSearchingHashtags = true

        hashtagSearchTask = Task {
            do {
                // Add a small delay to avoid too many API calls
                try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

                guard !Task.isCancelled else { return }

                // Search for posts with this hashtag
                let searchQuery = query.isEmpty ? "popular" : "#\(query)"
                let response = try await client.searchPosts(query: searchQuery, limit: 20)

                guard !Task.isCancelled else { return }

                // Extract unique hashtags from posts
                var hashtags = Set<String>()
                for post in response.posts {
                    if let tags = post.record.tags {
                        for tag in tags {
                            hashtags.insert(tag)
                        }
                    }
                }

                // Convert to sorted array and filter by query
                let filteredHashtags = hashtags.sorted().filter { tag in
                    query.isEmpty || tag.lowercased().hasPrefix(query.lowercased())
                }

                hashtagSuggestions = Array(filteredHashtags.prefix(10))
                isSearchingHashtags = false
                print("✅ Found \(hashtagSuggestions.count) hashtag suggestions for '\(query)'")
            } catch {
                if !Task.isCancelled {
                    print("Failed to search hashtags: \(error)")
                    isSearchingHashtags = false
                }
            }
        }
    }

    func insertHashtag(_ tag: String) {
        let cursorIndex = min(cursorPosition, text.count)
        let textBeforeCursor = String(text.prefix(cursorIndex))

        // Find the last # symbol
        if let lastHashIndex = textBeforeCursor.lastIndex(of: "#") {
            let beforeHash = String(text.prefix(upTo: lastHashIndex))
            let afterCursor = String(text.suffix(from: text.index(text.startIndex, offsetBy: cursorIndex)))

            // Insert the hashtag
            let hashtag = "#\(tag) "
            text = beforeHash + hashtag + afterCursor

            // Update cursor position to after the inserted hashtag
            cursorPosition = beforeHash.count + hashtag.count

            // Clear suggestions
            clearHashtagSuggestions()
        }
    }

    func clearHashtagSuggestions() {
        currentHashtagQuery = nil
        hashtagSuggestions = []
        isSearchingHashtags = false
        hashtagSearchTask?.cancel()
    }

    func post() async -> Bool {
        guard canPost else { return false }

        isPosting = true
        errorMessage = nil

        do {
            // Upload images if any are selected
            var uploadedImages: [UploadedImage] = []
            for (index, image) in selectedImages.enumerated() {
                let altText = index < imageAltTexts.count ? imageAltTexts[index] : nil
                let finalAltText = (altText?.isEmpty == false) ? altText : nil
                if let uploaded = try await client.uploadImage(image, altText: finalAltText) {
                    uploadedImages.append(uploaded)
                }
            }

            _ = try await client.createPost(text: text, reply: replyTo, images: uploadedImages.isEmpty ? nil : uploadedImages, langs: [selectedLanguage.id], moderationSettings: moderationSettings)

            // Track post creation
            Analytics.logEvent("post_created", parameters: [
                "post_type": replyTo != nil ? "reply" : "original",
                "character_count": text.count,
                "has_media": !selectedImages.isEmpty,
                "media_count": selectedImages.count
            ])
            print("📊 Analytics: Logged post_created (\(replyTo != nil ? "reply" : "original"), \(selectedImages.count) images)")

            // Delete draft if this was from a draft
            if let draftId = currentDraftId {
                if let draft = DraftManager.shared.getDraft(id: draftId) {
                    DraftManager.shared.deleteDraft(draft)
                }
            }

            text = ""
            selectedImages = []
            selectedPhotoItems = []
            isPosting = false
            return true
        } catch let error as ATProtoError {
            // Use the detailed error message from ATProtoError
            errorMessage = error.localizedDescription
            isPosting = false
            print("❌ Post failed: \(error)")
            return false
        } catch {
            // Generic error - add PDS context
            let pdsURL = client.session?.pdsURL ?? "unknown"
            errorMessage = "Post failed: \(error.localizedDescription)\n\nPDS: \(pdsURL)"
            isPosting = false
            print("❌ Post failed with generic error: \(error)")
            return false
        }
    }

    func saveDraft() {
        guard canSaveDraft else { return }

        // Convert images to data
        let imageData = selectedImages.compactMap { $0.jpegData(compressionQuality: 0.8) }

        let draft = PostDraft(
            id: currentDraftId ?? UUID(),
            text: text,
            imageData: imageData,
            imageAltTexts: imageAltTexts,
            languageId: selectedLanguage.id,
            moderationSettings: moderationSettings
        )

        DraftManager.shared.saveDraft(draft)
        print("💾 Draft saved: \(draft.id)")
    }

    func deleteDraft() {
        if let draftId = currentDraftId,
           let draft = DraftManager.shared.getDraft(id: draftId) {
            DraftManager.shared.deleteDraft(draft)
            print("🗑️ Draft deleted: \(draftId)")
        }
    }
}

// MARK: - Uploaded Image Model
struct UploadedImage {
    let blob: BlobRef
    let aspectRatio: AspectRatio?
    let alt: String?

    struct AspectRatio {
        let width: Int
        let height: Int
    }
}

struct BlobRef: Codable {
    let type: String
    let ref: BlobLink
    let mimeType: String
    let size: Int

    enum CodingKeys: String, CodingKey {
        case type = "$type"
        case ref
        case mimeType
        case size
    }
}

struct BlobLink: Codable {
    let link: String

    enum CodingKeys: String, CodingKey {
        case link = "$link"
    }
}
