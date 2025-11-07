//
//  ModerationSettingsView.swift
//  Skyscraper
//
//  Comprehensive moderation settings view
//

import SwiftUI

struct ModerationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var preferences = ModerationPreferences.shared
    @EnvironmentObject var theme: AppTheme
    @State private var showingAddMutedWord = false
    @State private var newMutedWord = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Moderation Settings")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Control what content you see and how it's displayed")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    Divider()

                    // Adult Content Toggle
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Content filters")
                            .font(.headline)
                            .padding(.horizontal)

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Enable adult content")
                                    .foregroundStyle(.secondary)
                                Text("Adult content can only be enabled via the Web at bsky.app")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text("Disabled")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }

                    Divider()

                    // Content Filter Settings
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Content Filters")
                            .font(.headline)
                            .padding(.horizontal)

                        Text("Choose how different types of labeled content are displayed")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        ForEach(ContentLabel.allCases, id: \.self) { label in
                            ContentFilterRow(
                                label: label,
                                currentVisibility: preferences.settings.visibility(for: label),
                                onVisibilityChange: { newVisibility in
                                    preferences.settings.setVisibility(newVisibility, for: label)
                                }
                            )
                        }
                    }

                    Divider()

                    // Muted Words
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Muted Words")
                                .font(.headline)

                            Spacer()

                            Button(action: {
                                showingAddMutedWord = true
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(theme.accentColor)
                                    .font(.title3)
                            }
                        }
                        .padding(.horizontal)

                        if preferences.settings.mutedWords.isEmpty {
                            Text("No muted words. Tap + to add.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(preferences.settings.mutedWords, id: \.self) { word in
                                    HStack {
                                        Text(word)
                                            .font(.subheadline)

                                        Spacer()

                                        Button(action: {
                                            preferences.settings.mutedWords.removeAll { $0 == word }
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.red)
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    Divider()

                    // Feed Settings
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Feed Settings")
                            .font(.headline)
                            .padding(.horizontal)

                        Toggle(isOn: $preferences.settings.hideReposts) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Hide reposts")
                                    .foregroundStyle(.primary)
                                Text("Don't show reposts in your timeline")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal)

                        Toggle(isOn: $preferences.settings.hideReplies) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Hide replies")
                                    .foregroundStyle(.primary)
                                Text("Don't show reply threads in your timeline")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal)

                        Toggle(isOn: $preferences.settings.hideQuotePosts) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Hide quote posts")
                                    .foregroundStyle(.primary)
                                Text("Don't show quote posts in your timeline")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAddMutedWord) {
                AddMutedWordView(mutedWords: $preferences.settings.mutedWords)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Content Filter Row

struct ContentFilterRow: View {
    let label: ContentLabel
    let currentVisibility: LabelVisibility
    let onVisibilityChange: (LabelVisibility) -> Void
    @State private var showingDetail = false

    var body: some View {
        Button(action: {
            showingDetail = true
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    Text(label.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                HStack(spacing: 4) {
                    Text(currentVisibility.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .sheet(isPresented: $showingDetail) {
            ContentFilterDetailView(
                label: label,
                currentVisibility: currentVisibility,
                onVisibilityChange: onVisibilityChange
            )
        }
    }
}

// MARK: - Content Filter Detail View

struct ContentFilterDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var theme: AppTheme
    let label: ContentLabel
    let currentVisibility: LabelVisibility
    let onVisibilityChange: (LabelVisibility) -> Void
    @State private var selectedVisibility: LabelVisibility

    init(label: ContentLabel, currentVisibility: LabelVisibility, onVisibilityChange: @escaping (LabelVisibility) -> Void) {
        self.label = label
        self.currentVisibility = currentVisibility
        self.onVisibilityChange = onVisibilityChange
        self._selectedVisibility = State(initialValue: currentVisibility)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(label.displayName)
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(label.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    Divider()

                    // Options
                    VStack(spacing: 12) {
                        ForEach(LabelVisibility.allCases, id: \.self) { visibility in
                            Button(action: {
                                selectedVisibility = visibility
                            }) {
                                HStack(alignment: .top, spacing: 12) {
                                    // Radio button
                                    Image(systemName: selectedVisibility == visibility ? "circle.inset.filled" : "circle")
                                        .foregroundStyle(selectedVisibility == visibility ? theme.accentColor : .secondary)
                                        .font(.title3)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(visibility.displayName)
                                            .font(.body)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.primary)

                                        Text(visibility.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()
                                }
                                .padding()
                                .background(
                                    selectedVisibility == visibility ?
                                    theme.accentColor.opacity(0.1) :
                                    Color.secondary.opacity(0.05)
                                )
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
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
                    Button("Save") {
                        onVisibilityChange(selectedVisibility)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Add Muted Word View

struct AddMutedWordView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var mutedWords: [String]
    @State private var newWord = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add Muted Word")
                        .font(.headline)

                    Text("Posts containing this word will be hidden from your timeline")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                TextField("Enter word or phrase", text: $newWord)
                    .textFieldStyle(.roundedBorder)
                    .focused($isInputFocused)
                    .onSubmit {
                        addWord()
                    }

                Spacer()
            }
            .padding()
            .navigationTitle("Mute Word")
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
                    Button("Add") {
                        addWord()
                    }
                    .fontWeight(.semibold)
                    .disabled(newWord.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                isInputFocused = true
            }
        }
        .presentationDetents([.medium])
    }

    private func addWord() {
        let trimmed = newWord.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !mutedWords.contains(trimmed) else { return }

        mutedWords.append(trimmed)
        dismiss()
    }
}

#Preview {
    ModerationSettingsView()
        .environmentObject(AppTheme.shared)
}
