//
//  DeveloperNotesView.swift
//  Skyscraper
//
//  View to display developer notes in markdown format
//

import SwiftUI
import WebKit

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct DeveloperNotesView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var htmlContent: String = ""
    @State private var isLoading = true
    @State private var profileToShow: String?
    @State private var urlToOpen: URL?

    var body: some View {
        GeometryReader { proxy in
            let bottomInset = proxy.safeAreaInsets.bottom

            ZStack {
                if isLoading {
                    ProgressView()
                } else {
                    MarkdownWebView(
                        htmlContent: htmlContent,
                        profileToShow: $profileToShow,
                        urlToOpen: $urlToOpen,
                        bottomInset: bottomInset
                    )
                }
            }
        }
        .navigationTitle("Developer Notes")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationDestination(item: Binding(
            get: { profileToShow.map { ProfileWrapper(actor: $0) } },
            set: { profileToShow = $0?.actor }
        )) { wrapper in
            ProfileView(actor: wrapper.actor)
        }
        .sheet(item: Binding(
            get: { urlToOpen.map { URLWrapper(url: $0) } },
            set: { urlToOpen = $0?.url }
        )) { wrapper in
            SafariView(url: wrapper.url)
        }
        .onAppear {
            loadMarkdownContent()

            // Track Developer Notes view
            Analytics.logEvent("user_viewed_developer_notes", parameters: nil)
            print("📊 Analytics: Logged user_viewed_developer_notes")
        }
    }

    private func loadMarkdownContent() {
        guard let url = Bundle.main.url(forResource: "DeveloperNotes", withExtension: "md"),
              let markdownContent = try? String(contentsOf: url, encoding: .utf8) else {
            htmlContent = convertMarkdownToHTML("# Developer Notes\n\nNo notes available at this time.")
            isLoading = false
            return
        }

        htmlContent = convertMarkdownToHTML(markdownContent)
        isLoading = false
    }

    private func convertMarkdownToHTML(_ markdown: String) -> String {
        // Use AttributedString to convert markdown, then get HTML-like styling
        // This is a simple conversion - for production you might want a proper markdown parser
        var html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                html, body {
                    height: 100%;
                }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
                    font-size: 16px;
                    line-height: 1.5;
                    padding: 16px;
                    margin: 0;
                    color: #000;
                    background-color: #fff;
                    box-sizing: border-box;
                }
                @media (prefers-color-scheme: dark) {
                    body {
                        color: #fff;
                        background-color: #000;
                    }
                    a {
                        color: #0a84ff;
                    }
                }
                h1 {
                    font-size: 28px;
                    font-weight: bold;
                    margin-top: 0;
                    margin-bottom: 12px;
                }
                h2 {
                    font-size: 22px;
                    font-weight: bold;
                    margin-top: 20px;
                    margin-bottom: 8px;
                }
                h3 {
                    font-size: 18px;
                    font-weight: bold;
                    margin-top: 16px;
                    margin-bottom: 6px;
                }
                p {
                    margin-top: 0;
                    margin-bottom: 8px;
                }
                a {
                    color: #007aff;
                    text-decoration: none;
                }
                ul, ol {
                    padding-left: 24px;
                    margin-bottom: 8px;
                    margin-top: 4px;
                }
                li {
                    margin-bottom: 4px;
                }
                hr {
                    border: none;
                    border-top: 1px solid #ddd;
                    margin: 20px 0;
                }
                @media (prefers-color-scheme: dark) {
                    hr {
                        border-top-color: #333;
                    }
                }
                em {
                    font-style: italic;
                }
                strong {
                    font-weight: bold;
                }
                code {
                    font-family: 'Courier New', monospace;
                    background-color: #f4f4f4;
                    padding: 2px 4px;
                    border-radius: 3px;
                }
                @media (prefers-color-scheme: dark) {
                    code {
                        background-color: #1c1c1e;
                    }
                }
            </style>
        </head>
        <body>
        """

        // Basic markdown to HTML conversion
        let lines = markdown.components(separatedBy: .newlines)
        var inList = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                // Skip empty lines - spacing handled by CSS margins
                continue
            }

            // Headers
            if trimmed.hasPrefix("### ") {
                html += "<h3>\(trimmed.dropFirst(4))</h3>"
            } else if trimmed.hasPrefix("## ") {
                html += "<h2>\(trimmed.dropFirst(3))</h2>"
            } else if trimmed.hasPrefix("# ") {
                html += "<h1>\(trimmed.dropFirst(2))</h1>"
            }
            // Lists
            else if trimmed.hasPrefix("- ") {
                if !inList {
                    html += "<ul>"
                    inList = true
                }
                html += "<li>\(processInlineMarkdown(String(trimmed.dropFirst(2))))</li>"
            }
            // Horizontal rule
            else if trimmed.hasPrefix("---") {
                if inList {
                    html += "</ul>"
                    inList = false
                }
                html += "<hr>"
            }
            // Regular paragraph
            else {
                if inList {
                    html += "</ul>"
                    inList = false
                }
                html += "<p>\(processInlineMarkdown(trimmed))</p>"
            }
        }

        if inList {
            html += "</ul>"
        }

        html += """
        </body>
        </html>
        """

        return html
    }

    private func processInlineMarkdown(_ text: String) -> String {
        var result = text

        // Links [text](url)
        let linkPattern = #"\[([^\]]+)\]\(([^\)]+)\)"#
        if let regex = try? NSRegularExpression(pattern: linkPattern, options: []) {
            let nsString = result as NSString
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: nsString.length))

            for match in matches.reversed() {
                if match.numberOfRanges == 3 {
                    let linkText = nsString.substring(with: match.range(at: 1))
                    let linkURL = nsString.substring(with: match.range(at: 2))
                    let replacement = "<a href=\"\(linkURL)\">\(linkText)</a>"
                    result = (result as NSString).replacingCharacters(in: match.range, with: replacement)
                }
            }
        }

        // Bold **text**
        result = result.replacingOccurrences(of: #"\*\*([^\*]+)\*\*"#, with: "<strong>$1</strong>", options: .regularExpression)

        // Italic *text*
        result = result.replacingOccurrences(of: #"\*([^\*]+)\*"#, with: "<em>$1</em>", options: .regularExpression)

        return result
    }
}

// MARK: - Markdown WebView

#if os(iOS)
struct MarkdownWebView: UIViewRepresentable {
    let htmlContent: String
    @Binding var profileToShow: String?
    @Binding var urlToOpen: URL?
    let bottomInset: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic

        let padding = max(bottomInset, 0) + 120
        webView.scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: padding, right: 0)
        webView.scrollView.verticalScrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: padding, right: 0)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let padding = max(bottomInset, 0) + 120
        if webView.scrollView.contentInset.bottom != padding {
            webView.scrollView.contentInset.bottom = padding
            webView.scrollView.verticalScrollIndicatorInsets.bottom = padding
        }

        webView.loadHTMLString(htmlContent, baseURL: nil)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: MarkdownWebView

        init(_ parent: MarkdownWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated {
                if let url = navigationAction.request.url {
                    // Check if it's a Bluesky profile URL
                    if url.host == "bsky.app",
                       url.pathComponents.count >= 3,
                       url.pathComponents[1] == "profile" {
                        let handle = url.pathComponents[2]

                        // Only set profileToShow if we have a valid handle
                        if !handle.isEmpty && handle != "/" {
                            parent.profileToShow = handle
                            decisionHandler(.cancel)
                            return
                        }
                    }

                    // Validate URL before opening
                    if url.scheme == "http" || url.scheme == "https" || url.scheme == "mailto" {
                        parent.urlToOpen = url
                        decisionHandler(.cancel)
                        return
                    }

                    // Invalid URL scheme - log and cancel
                    AppLogger.warning("Invalid URL scheme in Developer Notes: \(url.absoluteString)", subsystem: "UI")
                    decisionHandler(.cancel)
                    return
                }
            }

            decisionHandler(.allow)
        }
    }
}
#elseif os(macOS)
struct MarkdownWebView: NSViewRepresentable {
    let htmlContent: String
    @Binding var profileToShow: String?
    @Binding var urlToOpen: URL?
    let bottomInset: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(htmlContent, baseURL: nil)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: MarkdownWebView

        init(_ parent: MarkdownWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated {
                if let url = navigationAction.request.url {
                    // Check if it's a Bluesky profile URL
                    if url.host == "bsky.app",
                       url.pathComponents.count >= 3,
                       url.pathComponents[1] == "profile" {
                        let handle = url.pathComponents[2]

                        // Only set profileToShow if we have a valid handle
                        if !handle.isEmpty && handle != "/" {
                            parent.profileToShow = handle
                            decisionHandler(.cancel)
                            return
                        }
                    }

                    // Validate URL before opening
                    if url.scheme == "http" || url.scheme == "https" || url.scheme == "mailto" {
                        parent.urlToOpen = url
                        decisionHandler(.cancel)
                        return
                    }

                    // Invalid URL scheme - log and cancel
                    AppLogger.warning("Invalid URL scheme in Developer Notes: \(url.absoluteString)", subsystem: "UI")
                    decisionHandler(.cancel)
                    return
                }
            }

            decisionHandler(.allow)
        }
    }
}
#endif

#Preview {
    NavigationStack {
        DeveloperNotesView()
    }
}
