//
//  RetryableAsyncImage.swift
//  Skyscraper
//
//  Async image view with automatic retry logic for failed loads
//

import SwiftUI

/// An image view that automatically retries loading if it fails
struct RetryableAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let maxRetries: Int
    let retryDelay: TimeInterval
    let useExponentialBackoff: Bool
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var retryCount = 0
    @State private var imageKey = UUID()

    init(
        url: URL?,
        maxRetries: Int = 3,
        retryDelay: TimeInterval = 1.0,
        useExponentialBackoff: Bool = true,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.maxRetries = maxRetries
        self.retryDelay = retryDelay
        self.useExponentialBackoff = useExponentialBackoff
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                content(image)
            case .failure(_):
                // Show placeholder while retrying
                ZStack {
                    placeholder()

                    // Show retry indicator if still retrying
                    if retryCount < maxRetries {
                        LoadingIndicatorView()
                    }
                }
                .onAppear {
                    scheduleRetry()
                }
            case .empty:
                // Show prominent loading indicator during initial load
                ZStack {
                    placeholder()
                    LoadingIndicatorView()
                }
            @unknown default:
                placeholder()
            }
        }
        .id(imageKey) // Force reload when key changes
    }

    private func scheduleRetry() {
        guard retryCount < maxRetries else {
            print("❌ Max retries reached (\(maxRetries)) for URL: \(url?.absoluteString ?? "nil")")
            return
        }

        retryCount += 1

        // Use either exponential backoff or fixed delay
        let delay = useExponentialBackoff
            ? retryDelay * pow(1.5, Double(retryCount - 1))
            : retryDelay

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            print("🔄 Retrying image load (attempt \(retryCount)/\(maxRetries)) for URL: \(url?.absoluteString ?? "nil")")
            imageKey = UUID() // Trigger reload by changing the id
        }
    }
}

// MARK: - Convenience Initializers

extension RetryableAsyncImage where Content == AnyView, Placeholder == AnyView {
    /// Convenience initializer for simple image display
    init(
        url: URL?,
        maxRetries: Int = 3,
        retryDelay: TimeInterval = 1.0,
        useExponentialBackoff: Bool = true
    ) where Content == AnyView, Placeholder == AnyView {
        self.init(
            url: url,
            maxRetries: maxRetries,
            retryDelay: retryDelay,
            useExponentialBackoff: useExponentialBackoff,
            content: { image in
                AnyView(image.resizable())
            },
            placeholder: {
                AnyView(Color.gray.opacity(0.3))
            }
        )
    }
}

// MARK: - Loading Indicator

/// A prominent loading indicator with shimmer animation for image loading states
struct LoadingIndicatorView: View {
    @State private var isAnimating = false
    var size: CGFloat = 60
    var spinnerScale: CGFloat = 1.2
    var tintColor: Color = .gray

    var body: some View {
        ZStack {
            // Pulsing background
            Circle()
                .fill(tintColor.opacity(0.2))
                .frame(width: size, height: size)
                .scaleEffect(isAnimating ? 1.1 : 0.9)
                .opacity(isAnimating ? 0.3 : 0.6)

            // Spinner
            ProgressView()
                .scaleEffect(spinnerScale)
                .tint(tintColor)
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.0)
                .repeatForever(autoreverses: true)
            ) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Avatar-specific variant

struct AvatarImage: View {
    let url: URL?
    let size: CGFloat
    let borderWidth: CGFloat
    @EnvironmentObject var theme: AppTheme

    init(url: URL?, size: CGFloat, borderWidth: CGFloat = 4) {
        self.url = url
        self.size = size
        self.borderWidth = borderWidth
    }

    var body: some View {
        RetryableAsyncImage(
            url: url,
            maxRetries: 20,  // Retry 20 times (100 seconds total = ~1m 40s)
            retryDelay: 5.0,  // Fixed 5 seconds between retries
            useExponentialBackoff: false,  // Use consistent delay, not exponential
            content: { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            },
            placeholder: {
                Circle()
                    .fill(Color.blue.gradient)
            }
        )
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(theme.accentColor, lineWidth: borderWidth)
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Test with invalid URL to see retry behavior
        AvatarImage(
            url: URL(string: "https://invalid-url.example.com/avatar.jpg"),
            size: 48
        )

        // Test with valid URL
        AvatarImage(
            url: URL(string: "https://via.placeholder.com/150"),
            size: 48
        )
    }
    .padding()
    .environmentObject(AppTheme.shared)
}
