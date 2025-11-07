//
//  View+ScrollToTop.swift
//  Skyscraper
//
//  Enables status bar tap to scroll to top
//

import SwiftUI

#if os(iOS)
import UIKit
#endif

// MARK: - ScrollToTop ViewModifier

struct ScrollToTopModifier<ID: Hashable>: ViewModifier {
    @Binding var scrollPosition: ID?
    let firstItemID: ID?

    func body(content: Content) -> some View {
        #if os(iOS)
        content
            .background(
                ScrollToTopEnabler(scrollPosition: $scrollPosition, firstItemID: firstItemID)
                    .frame(width: 0, height: 0)
            )
        #else
        // macOS doesn't have status bar tap functionality
        content
        #endif
    }
}

#if os(iOS)
// MARK: - UIScrollView Enabler (iOS only)

private struct ScrollToTopEnabler<ID: Hashable>: UIViewRepresentable {
    @Binding var scrollPosition: ID?
    let firstItemID: ID?

    func makeUIView(context: Context) -> InvisibleView {
        let view = InvisibleView()
        return view
    }

    func updateUIView(_ uiView: InvisibleView, context: Context) {
        // Update the callback closure
        uiView.onScrollToTop = { [firstItemID] in
            if let firstID = firstItemID {
                DispatchQueue.main.async {
                    print("📜 Status bar tap: Scrolling to top (first post ID)")
                    withAnimation(.easeInOut(duration: 0.3)) {
                        scrollPosition = firstID
                    }
                }
            }
        }

        // Find and configure the scroll view
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let scrollView = findScrollView(in: uiView) {
                scrollView.scrollsToTop = true
                // Set the delegate to intercept scrollsToTop
                if scrollView.delegate == nil || !(scrollView.delegate is ScrollToTopDelegate) {
                    let delegate = ScrollToTopDelegate()
                    delegate.onScrollToTop = uiView.onScrollToTop
                    scrollView.delegate = delegate
                    print("✅ Enabled scrollsToTop for UIScrollView with delegate")
                }
            }
        }
    }

    private func findScrollView(in view: UIView) -> UIScrollView? {
        // Search up the parent hierarchy
        var currentView: UIView? = view.superview
        while let view = currentView {
            if let scrollView = view as? UIScrollView {
                return scrollView
            }
            currentView = view.superview
        }

        // Search in window's subviews as fallback
        if let window = view.window {
            return findScrollView(in: window.subviews)
        }

        return nil
    }

    private func findScrollView(in views: [UIView]) -> UIScrollView? {
        for view in views {
            if let scrollView = view as? UIScrollView {
                return scrollView
            }
            if let found = findScrollView(in: view.subviews) {
                return found
            }
        }
        return nil
    }

    // Invisible UIView to inject into SwiftUI hierarchy
    class InvisibleView: UIView {
        var onScrollToTop: (() -> Void)?

        override init(frame: CGRect) {
            super.init(frame: frame)
            isHidden = false
            isUserInteractionEnabled = false
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override var intrinsicContentSize: CGSize {
            .zero
        }
    }

    // Delegate to intercept scrollViewShouldScrollToTop
    private class ScrollToTopDelegate: NSObject, UIScrollViewDelegate {
        var onScrollToTop: (() -> Void)?

        func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
            // Trigger our custom action
            onScrollToTop?()
            // Return false to prevent UIKit's default scroll behavior
            // (we handle it in SwiftUI instead)
            return false
        }
    }
}
#endif

// MARK: - View Extension

extension View {
    /// Enables tap-status-bar-to-scroll-to-top functionality (iOS UIKit behavior)
    ///
    /// When applied to a ScrollView with scrollPosition binding, allows users to tap
    /// the status bar to automatically scroll to the first item.
    ///
    /// - Parameters:
    ///   - scrollPosition: Binding to the scroll position ID
    ///   - firstItemID: The ID of the first item to scroll to
    ///
    /// Usage:
    /// ```swift
    /// ScrollView {
    ///     LazyVStack {
    ///         ForEach(items) { item in
    ///             // content
    ///         }
    ///     }
    /// }
    /// .scrollPosition(id: $scrollPosition)
    /// .scrollsToTop(scrollPosition: $scrollPosition, firstItemID: items.first?.id)
    /// ```
    func scrollsToTop<ID: Hashable>(scrollPosition: Binding<ID?>, firstItemID: ID?) -> some View {
        modifier(ScrollToTopModifier(scrollPosition: scrollPosition, firstItemID: firstItemID))
    }

    /// Disables tap-status-bar-to-scroll-to-top for this scroll view
    ///
    /// Use this on secondary scroll views (sheets, modals, etc.) to ensure
    /// only the main timeline responds to status bar taps.
    func disableScrollsToTop() -> some View {
        #if os(iOS)
        background(
            DisableScrollsToTopView()
                .frame(width: 0, height: 0)
        )
        #else
        self
        #endif
    }
}

#if os(iOS)
// MARK: - Disable ScrollsToTop Helper

private struct DisableScrollsToTopView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isHidden = true
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let scrollView = findScrollView(in: uiView) {
                scrollView.scrollsToTop = false
                AppLogger.debug("Disabled scrollsToTop for UIScrollView", subsystem: "Scroll")
            }
        }
    }

    private func findScrollView(in view: UIView) -> UIScrollView? {
        var currentView: UIView? = view.superview
        while let view = currentView {
            if let scrollView = view as? UIScrollView {
                return scrollView
            }
            currentView = view.superview
        }
        return nil
    }
}
#endif
