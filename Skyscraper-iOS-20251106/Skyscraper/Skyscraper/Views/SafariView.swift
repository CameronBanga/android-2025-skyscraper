//
//  SafariView.swift
//  Skyscraper
//
//  SwiftUI wrapper for SFSafariViewController (iOS) / Opens in browser (macOS)
//

import SwiftUI

#if os(iOS)
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = false

        let safari = SFSafariViewController(url: url, configuration: configuration)
        return safari
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // No updates needed
    }
}
#elseif os(macOS)
import AppKit

// macOS: Open URL in default browser
struct SafariView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            Text("Opening in browser...")
                .padding()
        }
        .onAppear {
            NSWorkspace.shared.open(url)
            dismiss()
        }
    }
}
#endif
