//
//  ScrollToTopModifier.swift
//  Skyscraper
//
//  Enables UIKit scrollsToTop behavior for SwiftUI ScrollView
//  Allows tapping the status bar to scroll to top
//

import SwiftUI

#if os(iOS)
import UIKit

/// UIViewRepresentable that finds and enables scrollsToTop on UIScrollView
struct ScrollToTopIntrospectionView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isHidden = true
        view.isUserInteractionEnabled = false

        DispatchQueue.main.async {
            // Find the scroll view in the view hierarchy
            if let scrollView = view.findScrollView() {
                scrollView.scrollsToTop = true
            }
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            if let scrollView = uiView.findScrollView() {
                scrollView.scrollsToTop = true
            }
        }
    }
}

/// ViewModifier that enables scrollsToTop on the underlying UIScrollView
struct ScrollsToTopModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .overlay(ScrollToTopIntrospectionView())
    }
}

extension UIView {
    func findScrollView() -> UIScrollView? {
        // Check superview chain
        var currentView: UIView? = self
        while let view = currentView {
            if let scrollView = view as? UIScrollView {
                return scrollView
            }
            currentView = view.superview
        }

        // Check if parent has a scroll view in its subviews
        return superview?.subviews.compactMap { $0 as? UIScrollView }.first
    }
}

extension View {
    /// Enables scrollsToTop on the underlying UIScrollView
    /// This allows tapping the status bar to scroll to top
    func scrollsToTop(_ enabled: Bool = true) -> some View {
        #if os(iOS)
        modifier(ScrollsToTopModifier())
        #else
        self
        #endif
    }
}

#else
// macOS doesn't have scrollsToTop, so provide a no-op extension
extension View {
    func scrollsToTop(_ enabled: Bool = true) -> some View {
        self
    }
}
#endif
