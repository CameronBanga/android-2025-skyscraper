//
//  PostComposerView.swift
//  Skyscraper
//
//  Post composition view with character counter
//

import SwiftUI
import PhotosUI
import Foundation

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct PostComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: PostComposerViewModel
    @FocusState private var isFocused: Bool
    @EnvironmentObject var theme: AppTheme
    @State private var showToolbar = false
    @State private var showLanguagePicker = false
    @State private var showModerationSettings = false
    @State private var editingAltTextIndex: Int?
    @State private var showDraftsList = false
    @State private var showSaveDraftConfirmation = false

    let onPost: (Bool) -> Void

    init(replyTo: ReplyRef? = nil, draft: PostDraft? = nil, onPost: @escaping (Bool) -> Void) {
        _viewModel = StateObject(wrappedValue: PostComposerViewModel(replyTo: replyTo, draft: draft))
        self.onPost = onPost
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                textEditorView
                imagePreviewSection
                Spacer()
                mentionSuggestionsSection
                hashtagSuggestionsSection
                errorMessageSection
                bottomToolbar
            }
            #if os(macOS)
            .frame(minWidth: 500, minHeight: 400)
            #endif
            .navigationTitle("New Post")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if viewModel.canSaveDraft {
                            showSaveDraftConfirmation = true
                        } else {
                            dismiss()
                        }
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            let success = await viewModel.post()
                            if success {
                                dismiss()
                                onPost(true)
                            }
                        }
                    } label: {
                        if viewModel.isPosting {
                            ProgressView()
                        } else {
                            Text("Post")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!viewModel.canPost || viewModel.isPosting)
                }
            }
            .alert("Do you want to save this post as a draft?", isPresented: $showSaveDraftConfirmation) {
                Button("Save Draft") {
                    viewModel.saveDraft()
                    dismiss()
                }
                Button("Discard", role: .destructive) {
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            }
            .onAppear {
                isFocused = true
                // Delay showing the toolbar until after keyboard animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    showToolbar = true
                }
            }
        }
        .sheet(isPresented: $showLanguagePicker) {
            LanguagePickerView(selectedLanguage: $viewModel.selectedLanguage)
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showModerationSettings) {
            PostModerationSettingsView(settings: $viewModel.moderationSettings)
        }
        #else
        .sheet(isPresented: $showModerationSettings) {
            PostModerationSettingsView(settings: $viewModel.moderationSettings)
        }
        #endif
        .sheet(item: Binding(
            get: { editingAltTextIndex.map { AltTextEditWrapper(index: $0) } },
            set: { editingAltTextIndex = $0?.index }
        )) { wrapper in
            AltTextEditorView(
                altText: Binding(
                    get: { wrapper.index < viewModel.imageAltTexts.count ? viewModel.imageAltTexts[wrapper.index] : "" },
                    set: { viewModel.updateAltText(at: wrapper.index, text: $0) }
                ),
                image: wrapper.index < viewModel.selectedImages.count ? viewModel.selectedImages[wrapper.index] : nil
            )
            .environmentObject(theme)
        }
        .sheet(isPresented: $showDraftsList) {
            DraftsListView { draft in
                // Load the draft into the current composer
                viewModel.text = draft.text
                viewModel.imageAltTexts = draft.imageAltTexts
                viewModel.selectedLanguage = Language.allLanguages.first { $0.id == draft.languageId } ?? LanguagePreferences.shared.preferredLanguage
                viewModel.moderationSettings = draft.moderationSettings
                viewModel.selectedImages = draft.imageData.compactMap { PlatformImage(data: $0) }
            }
            .environmentObject(theme)
        }
    }

    // MARK: - Extracted Views

    private var textEditorView: some View {
        MentionTextEditor(
            text: $viewModel.text,
            cursorPosition: $viewModel.cursorPosition,
            accentColor: theme.accentColor
        )
        .focused($isFocused)
        #if os(macOS)
        .frame(minWidth: 300, maxWidth: .infinity, minHeight: 150, maxHeight: .infinity)
        #else
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
        .padding()
    }

    @ViewBuilder
    private var imagePreviewSection: some View {
        if !viewModel.selectedImages.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(viewModel.selectedImages.enumerated()), id: \.offset) { index, image in
                        imagePreviewItem(index: index, image: image)
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 120)
        }
    }

    private func imagePreviewItem(index: Int, image: PlatformImage) -> some View {
        ZStack(alignment: .topTrailing) {
            Button {
                editingAltTextIndex = index
            } label: {
                Group {
                    #if os(iOS)
                    Image(uiImage: image)
                        .resizable()
                    #else
                    Image(nsImage: image)
                        .resizable()
                    #endif
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .bottomLeading) {
                    if index < viewModel.imageAltTexts.count && !viewModel.imageAltTexts[index].isEmpty {
                        Text("ALT")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.black.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(4)
                    }
                }
            }

            Button {
                viewModel.removeImage(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .background(Circle().fill(.black.opacity(0.6)))
            }
            .padding(4)
        }
    }

    @ViewBuilder
    private var mentionSuggestionsSection: some View {
        if !viewModel.mentionSuggestions.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.mentionSuggestions, id: \.did) { profile in
                        mentionSuggestionButton(profile: profile)
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 60)
        }
    }

    private func mentionSuggestionButton(profile: Profile) -> some View {
        Button {
            viewModel.insertMention(profile)
        } label: {
            HStack(spacing: 8) {
                AvatarImage(
                    url: profile.avatar.flatMap { URL(string: $0) },
                    size: 32
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.displayName ?? profile.handle)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text("@\(profile.handle)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.accentColor.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(theme.accentColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var hashtagSuggestionsSection: some View {
        if !viewModel.hashtagSuggestions.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.hashtagSuggestions, id: \.self) { tag in
                        hashtagSuggestionButton(tag: tag)
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 60)
        }
    }

    private func hashtagSuggestionButton(tag: String) -> some View {
        Button {
            viewModel.insertHashtag(tag)
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(theme.accentColor.opacity(0.2))
                        .frame(width: 32, height: 32)

                    Image(systemName: "number")
                        .font(.system(size: 14))
                        .foregroundStyle(theme.accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("#\(tag)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.accentColor.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(theme.accentColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var errorMessageSection: some View {
        if let errorMessage = viewModel.errorMessage {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    private var bottomToolbar: some View {
        let accentColor = theme.accentColor // Capture before view builder

        return VStack(spacing: 8) {
            HStack {
                PhotosPicker(selection: $viewModel.selectedPhotoItems, maxSelectionCount: 4, matching: .any(of: [.images, .videos])) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title3)
                        .foregroundStyle(accentColor)
                        .padding(8)
                }
                .onChange(of: viewModel.selectedPhotoItems) { _, _ in
                    Task {
                        await viewModel.loadSelectedPhotos()
                    }
                }

                Spacer()

                Button {
                    showDraftsList = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text")
                            .font(.caption)
                        Text("Drafts")
                            .font(.caption)
                    }
                    .foregroundStyle(accentColor)
                }

                Text("·")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    showModerationSettings = true
                } label: {
                    Text(viewModel.moderationSettings.displaySummary)
                        .font(.caption)
                        .foregroundStyle(accentColor)
                        .lineLimit(1)
                }

                Text("·")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    showLanguagePicker = true
                } label: {
                    Text(viewModel.selectedLanguage.name)
                        .font(.caption)
                        .foregroundStyle(accentColor)
                }

                Text("\(viewModel.characterCount)/300")
                    .font(.caption)
                    .foregroundStyle(viewModel.characterCount > 300 ? .red : .secondary)
                    .padding(.leading, 4)
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 8)
        .opacity(showToolbar ? 1 : 0)
        .animation(.easeIn(duration: 0.2), value: showToolbar)
    }
}

// MARK: - Alt Text Edit Wrapper
struct AltTextEditWrapper: Identifiable {
    var id: Int { index }
    let index: Int
}

// MARK: - Mention Text Editor

#if os(iOS)
struct MentionTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var cursorPosition: Int
    let accentColor: Color

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = .systemFont(ofSize: 17)
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        textView.textContainer.lineFragmentPadding = 0

        // Set up attributed text with mention highlighting
        updateAttributedText(textView: textView, text: text)

        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // Only update if text changed (avoid cursor jumping)
        if uiView.text != text {
            updateAttributedText(textView: uiView, text: text)

            // Set cursor position
            let newPosition = min(cursorPosition, text.count)
            uiView.selectedRange = NSRange(location: newPosition, length: 0)
        } else if uiView.selectedRange.location != cursorPosition {
            // Update cursor position if it changed externally
            let newPosition = min(cursorPosition, text.count)
            uiView.selectedRange = NSRange(location: newPosition, length: 0)
        }
    }

    private func updateAttributedText(textView: UITextView, text: String) {
        let attributedString = NSMutableAttributedString(string: text)
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)

        // Default attributes
        attributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: 17), range: fullRange)
        attributedString.addAttribute(.foregroundColor, value: UIColor.label, range: fullRange)

        // Highlight mentions (including partial/incomplete ones)
        // Match @ followed by any word characters (letters, numbers, dots, dashes, underscores)
        let mentionPattern = #"@[a-zA-Z0-9._-]+"#
        if let regex = try? NSRegularExpression(pattern: mentionPattern) {
            let matches = regex.matches(in: text, range: fullRange)
            for match in matches {
                attributedString.addAttribute(.foregroundColor, value: UIColor(accentColor), range: match.range)
            }
        }

        // Highlight hashtags (including partial/incomplete ones)
        // Match # followed by any word characters
        let hashtagPattern = #"#[a-zA-Z0-9_]+"#
        if let regex = try? NSRegularExpression(pattern: hashtagPattern) {
            let matches = regex.matches(in: text, range: fullRange)
            for match in matches {
                attributedString.addAttribute(.foregroundColor, value: UIColor(accentColor), range: match.range)
            }
        }

        textView.attributedText = attributedString
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: MentionTextEditor

        init(_ parent: MentionTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            let currentText = textView.text ?? ""
            let currentPosition = textView.selectedRange.location

            // Update the parent binding
            parent.text = currentText
            parent.cursorPosition = currentPosition

            // Re-apply attributed text with highlighting
            parent.updateAttributedText(textView: textView, text: currentText)

            // Restore cursor position after applying attributed text
            textView.selectedRange = NSRange(location: currentPosition, length: 0)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            parent.cursorPosition = textView.selectedRange.location
        }
    }
}
#elseif os(macOS)
struct MentionTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var cursorPosition: Int
    let accentColor: Color

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        // Store reference to textView in coordinator
        context.coordinator.textView = textView

        textView.delegate = context.coordinator
        textView.font = .systemFont(ofSize: 17)
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.lineFragmentPadding = 0
        textView.isRichText = true
        textView.allowsUndo = true

        // IMPORTANT: Make the text view editable and selectable
        textView.isEditable = true
        textView.isSelectable = true
        textView.textContainer?.widthTracksTextView = true

        // Make sure scrollView doesn't interfere
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        // Make sure it can become first responder
        textView.usesFindBar = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false

        // Set up attributed text with mention highlighting
        updateAttributedText(textView: textView, text: text)

        // Try to make it first responder immediately
        DispatchQueue.main.async {
            scrollView.window?.makeFirstResponder(textView)
        }

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }

        // Ensure text view remains editable
        textView.isEditable = true
        textView.isSelectable = true

        // Only update if text changed (avoid cursor jumping)
        if textView.string != text {
            updateAttributedText(textView: textView, text: text)

            // Set cursor position
            let newPosition = min(cursorPosition, text.count)
            textView.setSelectedRange(NSRange(location: newPosition, length: 0))
        } else if textView.selectedRange().location != cursorPosition {
            // Update cursor position if it changed externally
            let newPosition = min(cursorPosition, text.count)
            textView.setSelectedRange(NSRange(location: newPosition, length: 0))
        }

        // Make sure the text view can become first responder
        // Keep trying until the window is available
        if !context.coordinator.hasSetInitialFocus {
            if nsView.window != nil {
                DispatchQueue.main.async {
                    nsView.window?.makeFirstResponder(textView)
                    context.coordinator.hasSetInitialFocus = true
                }
            }
        } else if textView.window != nil && textView.window?.firstResponder != textView {
            // If we've already tried but it's still not focused, try again
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }
        }
    }

    private func updateAttributedText(textView: NSTextView, text: String) {
        let attributedString = NSMutableAttributedString(string: text)
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)

        // Default attributes
        attributedString.addAttribute(.font, value: NSFont.systemFont(ofSize: 17), range: fullRange)
        attributedString.addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)

        // Highlight mentions (including partial/incomplete ones)
        let mentionPattern = #"@[a-zA-Z0-9._-]+"#
        if let regex = try? NSRegularExpression(pattern: mentionPattern) {
            let matches = regex.matches(in: text, range: fullRange)
            for match in matches {
                attributedString.addAttribute(.foregroundColor, value: NSColor(accentColor), range: match.range)
            }
        }

        // Highlight hashtags (including partial/incomplete ones)
        let hashtagPattern = #"#[a-zA-Z0-9_]+"#
        if let regex = try? NSRegularExpression(pattern: hashtagPattern) {
            let matches = regex.matches(in: text, range: fullRange)
            for match in matches {
                attributedString.addAttribute(.foregroundColor, value: NSColor(accentColor), range: match.range)
            }
        }

        textView.textStorage?.setAttributedString(attributedString)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MentionTextEditor
        var hasSetInitialFocus = false
        weak var textView: NSTextView?

        init(_ parent: MentionTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = self.textView else {
                print("⚠️ No textView reference in coordinator")
                return
            }

            let currentText = textView.string
            let currentPosition = textView.selectedRange().location

            print("📝 Text changed: '\(currentText)' (length: \(currentText.count))")
            print("📝 Current binding value: '\(parent.text)'")

            // Update the parent binding on the main thread
            DispatchQueue.main.async {
                self.parent.text = currentText
                self.parent.cursorPosition = currentPosition
                print("📝 Binding updated to: '\(self.parent.text)'")
            }

            // Re-apply attributed text with highlighting
            parent.updateAttributedText(textView: textView, text: currentText)

            // Restore cursor position after applying attributed text
            textView.setSelectedRange(NSRange(location: currentPosition, length: 0))
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = self.textView else {
                return
            }
            parent.cursorPosition = textView.selectedRange().location
        }
    }
}
#endif

#Preview {
    PostComposerView { _ in }
        .environmentObject(AppTheme.shared)
}
