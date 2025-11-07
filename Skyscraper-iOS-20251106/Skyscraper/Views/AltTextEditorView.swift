//
//  AltTextEditorView.swift
//  Skyscraper
//
//  Alt text editor for images in post composer
//

import SwiftUI

struct AltTextEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var altText: String
    let image: PlatformImage?
    @EnvironmentObject var theme: AppTheme
    @FocusState private var isFocused: Bool
    @State private var isGeneratingAltText = false
    @State private var showError = false
    @State private var errorMessage = ""

    private let maxCharacters = 1000

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Image preview
                if let image = image {
                    #if os(iOS)
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding()
                    #elseif os(macOS)
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding()
                    #endif
                }

                // Alt text input
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Alt Text")
                            .font(.headline)

                        // AI Generate button
                        if image != nil {
                            Button(action: {
                                generateAltText()
                            }) {
                                HStack(spacing: 4) {
                                    if isGeneratingAltText {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "sparkles")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                    }
                                }
                                .foregroundStyle(theme.accentColor)
                            }
                            .disabled(isGeneratingAltText)
                            .help("Generate alt text with AI")
                        }

                        Spacer()
                        Text("\(altText.count)/\(maxCharacters)")
                            .font(.caption)
                            .foregroundStyle(altText.count > maxCharacters ? .red : .secondary)
                    }
                    .padding(.horizontal)

                    TextEditor(text: $altText)
                        .focused($isFocused)
                        .frame(minHeight: 120)
                        .padding(8)
                        #if os(iOS)
                        .background(Color(uiColor: .secondarySystemBackground))
                        #elseif os(macOS)
                        .background(Color(nsColor: .controlBackgroundColor))
                        #endif
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.horizontal)

                    Text("Describe this image for people who can't see it. This helps make your posts more accessible.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .navigationTitle("Add Alt Text")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        // Track alt text addition if user added non-empty text
                        if !altText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Analytics.logEvent("user_added_alt_text", parameters: [
                                "character_count": altText.count
                            ])
                            print("📊 Analytics: Logged user_added_alt_text (\(altText.count) chars)")
                        }

                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(altText.count > maxCharacters)
                }
            }
            .onAppear {
                isFocused = true
            }
            .alert("Error Generating Alt Text", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .tint(theme.accentColor)
    }

    // MARK: - AI Alt Text Generation

    private func generateAltText() {
        guard let image = image else { return }

        isGeneratingAltText = true

        Task {
            do {
                let generatedText = try await ImageCaptionService.shared.generateAltText(for: image)

                await MainActor.run {
                    // If user hasn't typed anything, replace. Otherwise, append.
                    if altText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        altText = generatedText
                    } else {
                        // Ask user if they want to replace or append
                        altText = generatedText
                    }

                    isGeneratingAltText = false

                    // Track AI alt text generation
                    Analytics.logEvent("user_generated_ai_alt_text", parameters: [
                        "character_count": generatedText.count
                    ])
                    print("📊 Analytics: Logged user_generated_ai_alt_text")
                }
            } catch {
                await MainActor.run {
                    isGeneratingAltText = false
                    errorMessage = error.localizedDescription
                    showError = true

                    print("❌ Error generating alt text: \(error.localizedDescription)")
                }
            }
        }
    }
}

#Preview {
    #if os(iOS)
    AltTextEditorView(
        altText: .constant("A beautiful sunset over the ocean"),
        image: UIImage(systemName: "photo")
    )
    .environmentObject(AppTheme.shared)
    #else
    AltTextEditorView(
        altText: .constant("A beautiful sunset over the ocean"),
        image: nil
    )
    .environmentObject(AppTheme.shared)
    #endif
}
