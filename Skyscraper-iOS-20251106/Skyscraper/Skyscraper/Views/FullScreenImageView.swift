//
//  FullScreenImageView.swift
//  Skyscraper
//
//  Full-screen image viewer with pinch-to-zoom and swipe gestures
//

import SwiftUI

struct FullScreenImageView: View {
    let images: [ImageView]
    let initialIndex: Int
    @Environment(\.dismiss) var dismiss
    @State private var currentIndex: Int
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var dismissProgress: CGFloat = 0 // 0 = visible, 1 = dismissed
    @State private var isDismissing: Bool = false
    @State private var isAltTextExpanded: Bool = false
    @State private var showShareSheet = false
    @State private var imageToShare: UIImage?
    @State private var isDownloading = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    init(images: [ImageView], initialIndex: Int = 0) {
        self.images = images
        self.initialIndex = initialIndex
        _currentIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
                .opacity(1 - dismissProgress)

            // TabView handles left/right swiping natively
            TabView(selection: $currentIndex) {
                ForEach(Array(images.enumerated()), id: \.element.id) { index, image in
                    ZoomableImageView(
                        imageURL: URL(string: image.fullsize) ?? URL(string: image.thumb)!,
                        onVerticalDrag: handleVerticalDrag,
                        onVerticalDragEnd: handleVerticalDragEnd
                    )
                    .tag(index)
                }
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: images.count > 1 ? .always : .never))
            #endif
            .opacity(1 - dismissProgress)
            .onChange(of: currentIndex) { _, _ in
                // Reset alt text expansion when swiping to a different image
                isAltTextExpanded = false
            }

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.white, .black.opacity(0.5))
                    }
                    .padding()

                    Spacer()

                    if images.count > 1 {
                        Text("\(currentIndex + 1) / \(images.count)")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.5))
                            .clipShape(Capsule())
                    }

                    Spacer()

                    Menu {
                        Button {
                            Task {
                                await shareImage()
                            }
                        } label: {
                            SwiftUI.Label("Share Image", systemImage: "square.and.arrow.up")
                        }

                        Button {
                            Task {
                                await saveImage()
                            }
                        } label: {
                            SwiftUI.Label("Save to Photos", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.white, .black.opacity(0.5))
                    }
                    .padding()
                }

                Spacer()
                    .allowsHitTesting(false) // Only spacer ignores touches

                // Alt text display at bottom
                if currentIndex < images.count, !images[currentIndex].alt.isEmpty {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isAltTextExpanded.toggle()
                        }
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("ALT")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.white.opacity(0.3))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))

                                Spacer()

                                // Expand/collapse indicator
                                Image(systemName: isAltTextExpanded ? "chevron.down" : "chevron.up")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                            }

                            Text(images[currentIndex].alt)
                                .font(.subheadline)
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.leading)
                                .lineLimit(isAltTextExpanded ? nil : 3)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.black.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding()
                    }
                    .buttonStyle(.plain)
                }
            }
            .opacity(1 - dismissProgress)
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = imageToShare {
                ShareSheet(items: [image])
            }
        }
        .overlay {
            if isDownloading {
                ZStack {
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)

                        Text("Downloading image...")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }
                    .padding(24)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .alert("Saved", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Image saved to Photos")
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private func shareImage() async {
        guard currentIndex < images.count else {
            showError("Invalid image index")
            return
        }

        let imageURL = images[currentIndex].fullsize
        guard let url = URL(string: imageURL) else {
            showError("Invalid image URL")
            return
        }

        await MainActor.run { isDownloading = true }
        defer { Task { @MainActor in isDownloading = false } }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else {
                showError("Failed to load image")
                return
            }

            await MainActor.run {
                imageToShare = image
                showShareSheet = true
            }
        } catch {
            showError("Failed to download image: \(error.localizedDescription)")
        }
    }

    private func saveImage() async {
        guard currentIndex < images.count else {
            showError("Invalid image index")
            return
        }

        let imageURL = images[currentIndex].fullsize
        guard let url = URL(string: imageURL) else {
            showError("Invalid image URL")
            return
        }

        await MainActor.run { isDownloading = true }
        defer { Task { @MainActor in isDownloading = false } }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else {
                showError("Failed to load image")
                return
            }

            await MainActor.run {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                showSuccessAlert = true
            }
        } catch {
            showError("Failed to download image: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func showError(_ message: String) {
        errorMessage = message
        showErrorAlert = true
        AppLogger.error("Image download/save failed in fullscreen view", error: nil, subsystem: "UI")
    }

    private func handleVerticalDrag(_ translation: CGFloat) {
        isDismissing = true
        dismissProgress = min(abs(translation) / 200.0, 1.0)
    }

    private func handleVerticalDragEnd(_ translation: CGFloat) {
        if abs(translation) > 100 {
            // Dismiss with fade
            withAnimation(.easeOut(duration: 0.2)) {
                dismissProgress = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                dismiss()
            }
        } else {
            // Reset
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                dismissProgress = 0
                isDismissing = false
            }
        }
    }
}

struct ZoomableImageView: View {
    let imageURL: URL
    let onVerticalDrag: (CGFloat) -> Void
    let onVerticalDragEnd: (CGFloat) -> Void

    @State private var image: UIImage?
    @State private var isLoading: Bool = true
    @State private var loadError: Bool = false

    var body: some View {
        ZStack {
            if let image = image {
                ZoomableScrollImageView(
                    image: image,
                    onVerticalDrag: onVerticalDrag,
                    onVerticalDragEnd: onVerticalDragEnd
                )
            } else if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(2.0)

                    Text("Loading image...")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                }
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.3), radius: 10)
                )
            } else if loadError {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.white.opacity(0.7))
                    Text("Failed to load image")
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.top, 8)
                }
            }
        }
        .task {
            await loadImage()
        }
    }

    private func loadImage() async {
        isLoading = true
        loadError = false

        // Try to load image with retries
        for attempt in 0..<3 {
            do {
                let (data, _) = try await URLSession.shared.data(from: imageURL)
                if let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        self.image = uiImage
                        self.isLoading = false
                    }
                    return
                }
            } catch {
                if attempt < 2 {
                    try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 second delay
                }
            }
        }

        await MainActor.run {
            self.isLoading = false
            self.loadError = true
        }
    }
}

// MARK: - UIScrollView-based Zoomable Image View
struct ZoomableScrollImageView: UIViewRepresentable {
    let image: UIImage
    let onVerticalDrag: (CGFloat) -> Void
    let onVerticalDragEnd: (CGFloat) -> Void

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.maximumZoomScale = 4.0
        scrollView.minimumZoomScale = 1.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = .clear
        scrollView.bouncesZoom = true

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.tag = 100
        scrollView.addSubview(imageView)

        // Add double-tap gesture
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        // Add pan gesture for dismiss
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        panGesture.delegate = context.coordinator
        scrollView.addGestureRecognizer(panGesture)

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        guard let imageView = scrollView.viewWithTag(100) as? UIImageView else { return }

        imageView.image = image

        // Update frame
        let scrollViewSize = scrollView.bounds.size
        let imageSize = image.size

        let widthScale = scrollViewSize.width / imageSize.width
        let heightScale = scrollViewSize.height / imageSize.height
        let minScale = min(widthScale, heightScale)

        scrollView.minimumZoomScale = minScale
        scrollView.zoomScale = minScale

        let imageViewSize = CGSize(
            width: imageSize.width * minScale,
            height: imageSize.height * minScale
        )

        imageView.frame = CGRect(
            x: (scrollViewSize.width - imageViewSize.width) / 2,
            y: (scrollViewSize.height - imageViewSize.height) / 2,
            width: imageViewSize.width,
            height: imageViewSize.height
        )

        scrollView.contentSize = imageViewSize
        context.coordinator.updateCenterOffset(for: scrollView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        let parent: ZoomableScrollImageView
        private var isDismissing = false
        private var initialZoomScale: CGFloat = 1.0

        init(_ parent: ZoomableScrollImageView) {
            self.parent = parent
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return scrollView.viewWithTag(100)
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            updateCenterOffset(for: scrollView)
        }

        func updateCenterOffset(for scrollView: UIScrollView) {
            guard let imageView = scrollView.viewWithTag(100) else { return }

            let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) * 0.5, 0)
            let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) * 0.5, 0)

            imageView.center = CGPoint(
                x: scrollView.contentSize.width * 0.5 + offsetX,
                y: scrollView.contentSize.height * 0.5 + offsetY
            )
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = gesture.view as? UIScrollView else { return }

            if scrollView.zoomScale > scrollView.minimumZoomScale {
                // Zoom out
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            } else {
                // Zoom in to the tap location
                let location = gesture.location(in: scrollView)
                let zoomRect = zoomRect(for: scrollView, scale: scrollView.maximumZoomScale / 2, center: location)
                scrollView.zoom(to: zoomRect, animated: true)
            }
        }

        private func zoomRect(for scrollView: UIScrollView, scale: CGFloat, center: CGPoint) -> CGRect {
            let width = scrollView.bounds.width / scale
            let height = scrollView.bounds.height / scale
            let x = center.x - (width / 2)
            let y = center.y - (height / 2)

            return CGRect(x: x, y: y, width: width, height: height)
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let scrollView = gesture.view as? UIScrollView else { return }

            let translation = gesture.translation(in: scrollView)
            let velocity = gesture.velocity(in: scrollView)

            // Only handle dismiss when not zoomed in
            guard scrollView.zoomScale <= scrollView.minimumZoomScale else { return }

            // Check if it's a vertical swipe
            let isVertical = abs(velocity.y) > abs(velocity.x) * 2

            if isVertical {
                switch gesture.state {
                case .changed:
                    if !isDismissing && abs(translation.y) > 10 {
                        isDismissing = true
                    }
                    if isDismissing {
                        parent.onVerticalDrag(translation.y)
                    }
                case .ended, .cancelled:
                    if isDismissing {
                        parent.onVerticalDragEnd(translation.y)
                        isDismissing = false
                    }
                default:
                    break
                }
            }
        }

        // Allow simultaneous gestures
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
    }
}
