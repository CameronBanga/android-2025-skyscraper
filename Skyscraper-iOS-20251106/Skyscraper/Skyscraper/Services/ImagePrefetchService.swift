//
//  ImagePrefetchService.swift
//  Skyscraper
//
//  Service for prefetching images before they're needed
//

import Foundation

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
class ImagePrefetchService {
    static let shared = ImagePrefetchService()

    private var prefetchTasks: [URL: Task<Void, Never>] = [:]
    private let maxConcurrentPrefetches = 3

    // Prefetch images for a list of posts
    func prefetchImages(for posts: [FeedViewPost]) {
        var urlsToPrefetch: [URL] = []

        for post in posts {
            // Collect image URLs from the post
            if let images = post.post.embed?.images {
                for image in images {
                    if let url = URL(string: image.thumb) {
                        urlsToPrefetch.append(url)
                    }
                }
            }

            // Collect video thumbnail URLs
            if let video = post.post.embed?.video, let thumbnailURL = video.thumbnail.flatMap({ URL(string: $0) }) {
                urlsToPrefetch.append(thumbnailURL)
            } else if let video = post.post.embed?.media?.video, let thumbnailURL = video.thumbnail.flatMap({ URL(string: $0) }) {
                urlsToPrefetch.append(thumbnailURL)
            }

            // Collect author avatar
            if let avatarURL = post.post.author.avatar.flatMap({ URL(string: $0) }) {
                urlsToPrefetch.append(avatarURL)
            }

            // Collect embedded post images
            if let embeddedRecord = post.post.embed?.record {
                if let authorAvatar = embeddedRecord.author?.avatar.flatMap({ URL(string: $0) }) {
                    urlsToPrefetch.append(authorAvatar)
                }
            }

            // Collect images from media embeds
            if let mediaImages = post.post.embed?.media?.images {
                for image in mediaImages {
                    if let url = URL(string: image.thumb) {
                        urlsToPrefetch.append(url)
                    }
                }
            }

            // Collect images from reply parent post
            if let reply = post.reply, let parent = reply.parent {
                // Parent author avatar
                if let parentAvatar = parent.author.avatar.flatMap({ URL(string: $0) }) {
                    urlsToPrefetch.append(parentAvatar)
                }

                // Parent post images
                if let parentImages = parent.embed?.images {
                    for image in parentImages {
                        if let url = URL(string: image.thumb) {
                            urlsToPrefetch.append(url)
                        }
                    }
                }

                // Parent post video thumbnail
                if let video = parent.embed?.video, let thumbnailURL = video.thumbnail.flatMap({ URL(string: $0) }) {
                    urlsToPrefetch.append(thumbnailURL)
                } else if let video = parent.embed?.media?.video, let thumbnailURL = video.thumbnail.flatMap({ URL(string: $0) }) {
                    urlsToPrefetch.append(thumbnailURL)
                }

                // Parent post media images
                if let mediaImages = parent.embed?.media?.images {
                    for image in mediaImages {
                        if let url = URL(string: image.thumb) {
                            urlsToPrefetch.append(url)
                        }
                    }
                }

                // Parent post external link thumbnail
                if let external = parent.embed?.external, let thumbURL = external.thumb.flatMap({ URL(string: $0) }) {
                    urlsToPrefetch.append(thumbURL)
                }
            }
        }

        // Limit to avoid overwhelming the network
        let urlsToFetch = Array(urlsToPrefetch.prefix(maxConcurrentPrefetches))

        for url in urlsToFetch {
            prefetchImage(url: url)
        }
    }

    // Prefetch images for a list of posts and wait for completion
    func prefetchImagesAndWait(for posts: [FeedViewPost]) async {
        var urlsToPrefetch: [URL] = []

        for post in posts {
            // Collect image URLs from the post
            if let images = post.post.embed?.images {
                for image in images {
                    if let url = URL(string: image.thumb) {
                        urlsToPrefetch.append(url)
                    }
                }
            }

            // Collect video thumbnail URLs
            if let video = post.post.embed?.video, let thumbnailURL = video.thumbnail.flatMap({ URL(string: $0) }) {
                urlsToPrefetch.append(thumbnailURL)
            } else if let video = post.post.embed?.media?.video, let thumbnailURL = video.thumbnail.flatMap({ URL(string: $0) }) {
                urlsToPrefetch.append(thumbnailURL)
            }

            // Collect author avatar
            if let avatarURL = post.post.author.avatar.flatMap({ URL(string: $0) }) {
                urlsToPrefetch.append(avatarURL)
            }

            // Collect embedded post images
            if let embeddedRecord = post.post.embed?.record {
                if let authorAvatar = embeddedRecord.author?.avatar.flatMap({ URL(string: $0) }) {
                    urlsToPrefetch.append(authorAvatar)
                }

                // Collect embedded post media images
                if let embeds = embeddedRecord.embeds {
                    for embed in embeds {
                        if let embedImages = embed.images {
                            for image in embedImages {
                                if let url = URL(string: image.thumb) {
                                    urlsToPrefetch.append(url)
                                }
                            }
                        }
                    }
                }
            }

            // Collect images from media embeds
            if let mediaImages = post.post.embed?.media?.images {
                for image in mediaImages {
                    if let url = URL(string: image.thumb) {
                        urlsToPrefetch.append(url)
                    }
                }
            }

            // Collect external link thumbnails
            if let external = post.post.embed?.external, let thumbURL = external.thumb.flatMap({ URL(string: $0) }) {
                urlsToPrefetch.append(thumbURL)
            }

            // Collect images from reply parent post
            if let reply = post.reply, let parent = reply.parent {
                // Parent author avatar
                if let parentAvatar = parent.author.avatar.flatMap({ URL(string: $0) }) {
                    urlsToPrefetch.append(parentAvatar)
                }

                // Parent post images
                if let parentImages = parent.embed?.images {
                    for image in parentImages {
                        if let url = URL(string: image.thumb) {
                            urlsToPrefetch.append(url)
                        }
                    }
                }

                // Parent post video thumbnail
                if let video = parent.embed?.video, let thumbnailURL = video.thumbnail.flatMap({ URL(string: $0) }) {
                    urlsToPrefetch.append(thumbnailURL)
                } else if let video = parent.embed?.media?.video, let thumbnailURL = video.thumbnail.flatMap({ URL(string: $0) }) {
                    urlsToPrefetch.append(thumbnailURL)
                }

                // Parent post media images
                if let mediaImages = parent.embed?.media?.images {
                    for image in mediaImages {
                        if let url = URL(string: image.thumb) {
                            urlsToPrefetch.append(url)
                        }
                    }
                }

                // Parent post external link thumbnail
                if let external = parent.embed?.external, let thumbURL = external.thumb.flatMap({ URL(string: $0) }) {
                    urlsToPrefetch.append(thumbURL)
                }
            }
        }

        // Remove duplicates
        let uniqueURLs = Array(Set(urlsToPrefetch))

        print("🖼️ Prefetching \(uniqueURLs.count) images for \(posts.count) posts...")

        // Prefetch all images concurrently
        await withTaskGroup(of: Void.self) { group in
            for url in uniqueURLs {
                group.addTask {
                    await self.prefetchImageAndWait(url: url)
                }
            }
        }

        print("✅ Completed prefetching \(uniqueURLs.count) images")
    }

    // Prefetch a single image
    private func prefetchImage(url: URL) {
        // Skip if already prefetching this URL
        guard prefetchTasks[url] == nil else { return }

        // Check if already in cache
        let request = URLRequest(url: url)
        if let _ = URLCache.shared.cachedResponse(for: request) {
            return // Already cached
        }

        let task = Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)

                // Cache the response
                let cachedResponse = CachedURLResponse(response: response, data: data)
                URLCache.shared.storeCachedResponse(cachedResponse, for: request)

                print("✅ Prefetched image: \(url.lastPathComponent)")
            } catch {
                print("❌ Failed to prefetch image: \(url.lastPathComponent) - \(error.localizedDescription)")
            }

            // Remove from tracking
            prefetchTasks[url] = nil
        }

        prefetchTasks[url] = task
    }

    // Prefetch a single image and wait for completion
    private func prefetchImageAndWait(url: URL) async {
        // Check if already in cache
        let request = URLRequest(url: url)
        if let _ = URLCache.shared.cachedResponse(for: request) {
            return // Already cached
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            // Pre-decode the image to ensure it's fully decompressed
            // This forces image decoding now rather than during rendering, preventing stutters
            if let _ = PlatformImage(data: data) {
                // Image successfully decoded - it's now in memory and ready
                // Cache the original data (decoding ensures it's processed for faster future loads)
                let cachedResponse = CachedURLResponse(response: response, data: data)
                URLCache.shared.storeCachedResponse(cachedResponse, for: request)
            } else {
                // If not an image, just cache the data
                let cachedResponse = CachedURLResponse(response: response, data: data)
                URLCache.shared.storeCachedResponse(cachedResponse, for: request)
            }
        } catch {
            // Silently fail - we'll show placeholder for failed images
            print("⚠️ Failed to prefetch \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }

    // Cancel all prefetch tasks
    func cancelAll() {
        for (_, task) in prefetchTasks {
            task.cancel()
        }
        prefetchTasks.removeAll()
    }

    // Cancel prefetch for specific URL
    func cancel(url: URL) {
        prefetchTasks[url]?.cancel()
        prefetchTasks[url] = nil
    }
}
