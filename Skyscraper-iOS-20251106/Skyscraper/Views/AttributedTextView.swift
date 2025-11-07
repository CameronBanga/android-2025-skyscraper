//
//  AttributedTextView.swift
//  Skyscraper
//
//  Renders post text with clickable links and mentions using facets from ATProtocol
//

import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum TappableItem {
    case url(URL)
    case mention(did: String)
    case hashtag(tag: String)
}

#if os(iOS)
struct AttributedTextView: UIViewRepresentable {
    let text: String
    let facets: [Facet]?
    let font: UIFont
    let textColor: UIColor
    let accentColor: Color
    let onItemTapped: (TappableItem) -> Void

    init(
        text: String,
        facets: [Facet]?,
        font: UIFont = .preferredFont(forTextStyle: .body),
        textColor: UIColor = .label,
        accentColor: Color,
        onItemTapped: @escaping (TappableItem) -> Void
    ) {
        self.text = text
        self.facets = facets
        self.font = font
        self.textColor = textColor
        self.accentColor = accentColor
        self.onItemTapped = onItemTapped
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        // Get the proposed width with a sensible fallback
        // If width is nil or infinite, use a default reasonable width (screen width - padding)
        let screenWidth = uiView.window?.windowScene?.screen.bounds.width ?? 375 // Fallback to common iPhone width
        let defaultWidth = screenWidth - 40 // Account for padding
        let proposedWidth = proposal.width ?? defaultWidth

        // Clamp to reasonable bounds to prevent infinite layout loops
        let width: CGFloat
        if proposedWidth.isInfinite || proposedWidth > 10000 {
            width = defaultWidth
        } else {
            width = max(100, proposedWidth) // Ensure minimum width of 100
        }

        // Ensure the text container size is set for proper layout calculation
        uiView.textContainer.size = CGSize(width: width, height: .greatestFiniteMagnitude)

        // Force layout to ensure the text container is updated
        uiView.layoutManager.ensureLayout(for: uiView.textContainer)

        // Calculate the size needed for the text
        let usedRect = uiView.layoutManager.usedRect(for: uiView.textContainer)
        let finalSize = CGSize(width: width, height: ceil(usedRect.height))

        return finalSize
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.textContainer.maximumNumberOfLines = 0 // No line limit
        // Don't track width - we'll set it explicitly in sizeThatFits
        textView.textContainer.widthTracksTextView = false
        textView.textContainer.heightTracksTextView = false
        // Set a large size initially
        textView.textContainer.size = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.delegate = context.coordinator
        // Convert SwiftUI Color to UIColor for link attributes
        textView.linkTextAttributes = [
            .foregroundColor: UIColor(accentColor)
        ]
        // Allow horizontal compression but resist vertical compression
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentCompressionResistancePriority(.required, for: .vertical)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        let attributedString = createAttributedString()

        textView.linkTextAttributes = [
            .foregroundColor: UIColor(accentColor)
        ]

        textView.attributedText = attributedString
        textView.font = font
        textView.textColor = textColor

        print("AttributedTextView: Updated text, length: \(attributedString.length)")

        // Force the text view to recalculate its size
        textView.invalidateIntrinsicContentSize()
        textView.setNeedsLayout()
        textView.layoutIfNeeded()

        // Notify SwiftUI that our size may have changed
        DispatchQueue.main.async {
            textView.invalidateIntrinsicContentSize()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onItemTapped: onItemTapped)
    }

    private func createAttributedString() -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: text)
        let accentUIColor = UIColor(accentColor)

        // Apply default styling
        let fullRange = NSRange(location: 0, length: attributedString.length)
        attributedString.addAttribute(.font, value: font, range: fullRange)
        attributedString.addAttribute(.foregroundColor, value: textColor, range: fullRange)

        // Apply facets (links, mentions, hashtags)
        guard let facets = facets else {
            print("AttributedTextView: No facets for text: \(text)")
            return attributedString
        }

        print("AttributedTextView: Processing \(facets.count) facets for text: \(text)")

        for facet in facets {
            // Convert byte indices to Swift String indices
            guard let range = byteRangeToNSRange(
                text: text,
                byteStart: facet.index.byteStart,
                byteEnd: facet.index.byteEnd
            ) else {
                print("AttributedTextView: Failed to convert byte range for facet")
                continue
            }

            // Apply styling based on feature type
            for feature in facet.features {
                switch feature {
                case .link(let urlString):
                    print("AttributedTextView: Found link: \(urlString)")
                    if let url = URL(string: urlString) {
                        attributedString.addAttribute(.link, value: url, range: range)
                        attributedString.addAttribute(.foregroundColor, value: accentUIColor, range: range)
                    }
                case .mention(let did):
                    // Use custom URL scheme for mentions so they're tappable
                    // Encode the DID in the path to preserve colons
                    print("AttributedTextView: Found mention with DID: \(did)")
                    if let mentionURL = URL(string: "mention://mention/\(did)") {
                        attributedString.addAttribute(.link, value: mentionURL, range: range)
                        // Make mentions bold to stand out
                        attributedString.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: font.pointSize), range: range)
                        attributedString.addAttribute(.foregroundColor, value: accentUIColor, range: range)
                    }
                case .tag(let tag):
                    print("AttributedTextView: Found tag: \(tag)")
                    // Use custom URL scheme for hashtags so they're tappable
                    if let tagURL = URL(string: "hashtag://\(tag)") {
                        attributedString.addAttribute(.link, value: tagURL, range: range)
                        attributedString.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: font.pointSize), range: range)
                        attributedString.addAttribute(.foregroundColor, value: accentUIColor, range: range)
                    }
                }
            }
        }

        return attributedString
    }

    private func byteRangeToNSRange(text: String, byteStart: Int, byteEnd: Int) -> NSRange? {
        guard byteStart >= 0,
              byteEnd >= byteStart,
              byteEnd <= text.utf8.count else {
            return nil
        }

        let utf8View = text.utf8

        guard let startUTF8 = utf8View.index(utf8View.startIndex, offsetBy: byteStart, limitedBy: utf8View.endIndex),
              let endUTF8 = utf8View.index(utf8View.startIndex, offsetBy: byteEnd, limitedBy: utf8View.endIndex),
              let startIndex = String.Index(startUTF8, within: text),
              let endIndex = String.Index(endUTF8, within: text),
              startIndex < endIndex else {
            return nil
        }

        return NSRange(startIndex..<endIndex, in: text)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        let onItemTapped: (TappableItem) -> Void

        init(onItemTapped: @escaping (TappableItem) -> Void) {
            self.onItemTapped = onItemTapped
        }

        // Modern iOS 17+ delegate method for link taps
        func textView(_ textView: UITextView, primaryActionFor textItem: UITextItem, defaultAction: UIAction) -> UIAction? {
            if case .link(let url) = textItem.content {
                return UIAction { [weak self] _ in
                    // Check if it's a mention, hashtag, or regular URL
                    if url.scheme == "mention" {
                        // Extract DID from path (format: mention://mention/did:plc:xyz)
                        let did = url.path.replacingOccurrences(of: "/", with: "")
                        self?.onItemTapped(.mention(did: did))
                    } else if url.scheme == "hashtag", let tag = url.host {
                        self?.onItemTapped(.hashtag(tag: tag))
                    } else {
                        self?.onItemTapped(.url(url))
                    }
                }
            }
            return defaultAction
        }
    }
}
#elseif os(macOS)
// Simplified macOS version using Text with AttributedString
struct AttributedTextView: View {
    let text: String
    let facets: [Facet]?
    let font: NSFont
    let textColor: NSColor
    let accentColor: Color
    let onItemTapped: (TappableItem) -> Void

    init(
        text: String,
        facets: [Facet]?,
        font: NSFont = .systemFont(ofSize: NSFont.systemFontSize),
        textColor: NSColor = .labelColor,
        accentColor: Color,
        onItemTapped: @escaping (TappableItem) -> Void
    ) {
        self.text = text
        self.facets = facets
        self.font = font
        self.textColor = textColor
        self.accentColor = accentColor
        self.onItemTapped = onItemTapped
    }

    var body: some View {
        // For now, use a simple Text view for macOS
        // Full facet support with clickable links can be added later if needed
        Text(text)
            .foregroundColor(Color(textColor))
    }
}
#endif
