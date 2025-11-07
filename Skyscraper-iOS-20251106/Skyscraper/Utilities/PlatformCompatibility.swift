//
//  PlatformCompatibility.swift
//  Skyscraper
//
//  Cross-platform type aliases and utilities for iOS and macOS
//

import Foundation
import SwiftUI

#if os(iOS)
import UIKit

// Type aliases for iOS
typealias PlatformImage = UIImage
typealias PlatformColor = UIColor
typealias PlatformFont = UIFont
typealias PlatformApplication = UIApplication

#elseif os(macOS)
import AppKit

// Type aliases for macOS
typealias PlatformImage = NSImage
typealias PlatformColor = NSColor
typealias PlatformFont = NSFont
typealias PlatformApplication = NSApplication

// NSImage extensions to match UIImage API
extension NSImage {
    var cgImage: CGImage? {
        var rect = CGRect(origin: .zero, size: size)
        return cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }

    // Removed duplicate init(data:) - NSImage already has this initializer

    func jpegData(compressionQuality: CGFloat) -> Data? {
        guard let tiffData = tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        let properties: [NSBitmapImageRep.PropertyKey: Any] = [
            .compressionFactor: compressionQuality
        ]

        return bitmapImage.representation(using: .jpeg, properties: properties)
    }

    func pngData() -> Data? {
        guard let tiffData = tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmapImage.representation(using: .png, properties: [:])
    }
}

#endif

// Cross-platform color conversion
extension Color {
    init(platformColor: PlatformColor) {
        #if os(iOS)
        self.init(uiColor: platformColor)
        #elseif os(macOS)
        self.init(nsColor: platformColor)
        #endif
    }
}

// Platform-specific utilities
struct PlatformUtilities {
    #if os(iOS)
    static var isIdleTimerDisabled: Bool {
        get { UIApplication.shared.isIdleTimerDisabled }
        set { UIApplication.shared.isIdleTimerDisabled = newValue }
    }

    static func setAlternateIconName(_ iconName: String?) async throws {
        try await UIApplication.shared.setAlternateIconName(iconName)
    }

    static var alternateIconName: String? {
        UIApplication.shared.alternateIconName
    }

    static var supportsAlternateIcons: Bool {
        UIApplication.shared.supportsAlternateIcons
    }
    #elseif os(macOS)
    // macOS doesn't support these features, provide no-op implementations
    static var isIdleTimerDisabled: Bool {
        get { false }
        set { /* no-op on macOS */ }
    }

    static func setAlternateIconName(_ iconName: String?) async throws {
        // no-op on macOS
    }

    static var alternateIconName: String? {
        return nil
    }

    static var supportsAlternateIcons: Bool {
        false
    }
    #endif
}
