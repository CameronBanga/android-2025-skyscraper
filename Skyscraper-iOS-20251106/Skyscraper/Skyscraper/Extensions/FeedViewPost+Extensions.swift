//
//  FeedViewPost+Extensions.swift
//  Skyscraper
//
//  Performance extensions for FeedViewPost
//

import Foundation

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

extension FeedViewPost {
    /// Estimated height for the post cell
    /// Used by LazyVStack for efficient scrolling and layout
    /// This prevents SwiftUI from having to layout every post to calculate scroll positions
    var estimatedHeight: CGFloat {
        var height: CGFloat = 0

        // Base height: avatar + author info + action buttons + padding
        height += 140

        // Text content estimation
        // Average character width ~8pt at body size, ~50 chars per line at typical phone width
        let textLength = post.record.text.count
        let estimatedLines = max(1, textLength / 50)
        let textHeight = CGFloat(estimatedLines) * 20 // ~20pt per line
        height += min(textHeight, 400) // Cap at reasonable max for very long posts

        // Reply context (parent post)
        if reply != nil {
            height += 130 // Fixed height for reply thread item
        }

        // Repost indicator
        if reason != nil {
            height += 20
        }

        // Media embeds
        if let images = post.embed?.images, !images.isEmpty {
            // Single image uses singleImageHeight (300)
            // Multiple images use calculated grid height
            if images.count == 1 {
                height += 300
            } else if images.count == 2 {
                height += 180
            } else if images.count == 3 {
                height += 180 + 4 + (180 * 0.75) // multiImageHeight + spacing + smaller cells
            } else {
                height += (180 * 0.75) * 2 + 4 // 2x2 grid
            }
        } else if let images = post.embed?.media?.images, !images.isEmpty {
            // Images from recordWithMedia (quote post with images)
            if images.count == 1 {
                height += 300
            } else {
                height += 180
            }
        }

        // Video embed
        if post.embed?.video != nil || post.embed?.media?.video != nil {
            height += 400
        }

        // External link preview
        if post.embed?.external != nil {
            height += 288 // imageHeight (200) + textContainerHeight (88)
        }

        // Quoted/embedded post
        if post.embed?.record != nil {
            height += 150 // Approximate embedded post height
        }

        return height
    }

    /// Calculate actual text height for more accurate layout
    /// This is called asynchronously before insertion for better performance
    nonisolated func calculateActualTextHeight(maxWidth: CGFloat) -> CGFloat {
        let text = post.record.text

        #if os(iOS)
        let font = UIFont.preferredFont(forTextStyle: .body)
        #elseif os(macOS)
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        #endif

        let constraintRect = CGSize(width: maxWidth - 32, height: .greatestFiniteMagnitude) // Account for padding
        let boundingBox = text.boundingRect(
            with: constraintRect,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )

        return ceil(boundingBox.height)
    }

    /// Create a copy of this FeedViewPost with an updated Post
    func withUpdatedPost(_ updatePost: (Post) -> Post) -> FeedViewPost {
        FeedViewPost(
            post: updatePost(self.post),
            reply: self.reply,
            reason: self.reason
        )
    }

    /// Create a copy with optimistically updated like state
    func withToggledLike() -> FeedViewPost {
        withUpdatedPost { post in
            var updatedPost = post
            let wasLiked = post.viewer?.like != nil

            if wasLiked {
                // Unlike
                updatedPost.likeCount = max(0, (post.likeCount ?? 0) - 1)
                updatedPost.viewer?.like = nil
            } else {
                // Like
                updatedPost.likeCount = (post.likeCount ?? 0) + 1

                // Ensure viewer exists before setting like
                if updatedPost.viewer == nil {
                    updatedPost.viewer = PostViewer(like: "pending", repost: nil, bookmarked: nil, threadMuted: nil, replyDisabled: nil, embeddingDisabled: nil)
                } else {
                    updatedPost.viewer?.like = "pending"
                }
            }

            return updatedPost
        }
    }

    /// Create a copy with optimistically toggled repost state
    func withToggledRepost() -> FeedViewPost {
        withUpdatedPost { post in
            var updatedPost = post
            let wasReposted = post.viewer?.repost != nil

            if wasReposted {
                // Unrepost
                updatedPost.repostCount = max(0, (post.repostCount ?? 0) - 1)
                updatedPost.viewer?.repost = nil
            } else {
                // Repost
                updatedPost.repostCount = (post.repostCount ?? 0) + 1

                // Ensure viewer exists before setting repost
                if updatedPost.viewer == nil {
                    updatedPost.viewer = PostViewer(like: nil, repost: "pending", bookmarked: nil, threadMuted: nil, replyDisabled: nil, embeddingDisabled: nil)
                } else {
                    updatedPost.viewer?.repost = "pending"
                }
            }

            return updatedPost
        }
    }
}
