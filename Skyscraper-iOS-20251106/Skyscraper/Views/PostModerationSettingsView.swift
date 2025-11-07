//
//  PostModerationSettingsView.swift
//  Skyscraper
//
//  Post interaction settings for moderation
//

import SwiftUI

struct PostModerationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var settings: PostModerationSettings
    @State private var allowQuotePosts: Bool
    @State private var replyMode: ReplyMode
    @State private var mentionedEnabled: Bool = false
    @State private var followingEnabled: Bool = false
    @State private var followersEnabled: Bool = false

    enum ReplyMode {
        case everybody
        case nobody
        case custom
    }

    init(settings: Binding<PostModerationSettings>) {
        self._settings = settings
        self._allowQuotePosts = State(initialValue: settings.wrappedValue.allowQuotePosts)

        // Initialize reply mode based on current restriction
        switch settings.wrappedValue.replyRestriction {
        case .everybody:
            self._replyMode = State(initialValue: .everybody)
        case .nobody:
            self._replyMode = State(initialValue: .nobody)
        case .mentioned:
            self._replyMode = State(initialValue: .custom)
            self._mentionedEnabled = State(initialValue: true)
        case .following:
            self._replyMode = State(initialValue: .custom)
            self._followingEnabled = State(initialValue: true)
        case .followers:
            self._replyMode = State(initialValue: .custom)
            self._followersEnabled = State(initialValue: true)
        case .combined(let mentioned, let following, let followers):
            self._replyMode = State(initialValue: .custom)
            self._mentionedEnabled = State(initialValue: mentioned)
            self._followingEnabled = State(initialValue: following)
            self._followersEnabled = State(initialValue: followers)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Post interaction settings")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Customize who can interact with this post.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    Divider()

                    // Quote settings
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quote settings")
                            .font(.headline)
                            .padding(.horizontal)

                        Toggle(isOn: $allowQuotePosts) {
                            Text("Allow quote posts")
                                .foregroundStyle(.primary)
                        }
                        .padding(.horizontal)
                    }

                    Divider()

                    // Reply settings
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Reply settings")
                            .font(.headline)
                            .padding(.horizontal)

                        Text("Allow replies from:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        // Primary options
                        HStack(spacing: 12) {
                            OptionButton(
                                title: "Everybody",
                                isSelected: replyMode == .everybody
                            ) {
                                replyMode = .everybody
                            }

                            OptionButton(
                                title: "Nobody",
                                isSelected: replyMode == .nobody
                            ) {
                                replyMode = .nobody
                            }
                        }
                        .padding(.horizontal)

                        // Combined options
                        Text("Or combine these options:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 8)

                        VStack(spacing: 12) {
                            CustomOptionButton(
                                title: "Mentioned users",
                                isEnabled: $mentionedEnabled,
                                isActive: replyMode == .custom
                            ) {
                                if !mentionedEnabled && !followingEnabled && !followersEnabled {
                                    replyMode = .custom
                                }
                            }

                            CustomOptionButton(
                                title: "Users you follow",
                                isEnabled: $followingEnabled,
                                isActive: replyMode == .custom
                            ) {
                                if !mentionedEnabled && !followingEnabled && !followersEnabled {
                                    replyMode = .custom
                                }
                            }

                            CustomOptionButton(
                                title: "Your followers",
                                isEnabled: $followersEnabled,
                                isActive: replyMode == .custom
                            ) {
                                if !mentionedEnabled && !followingEnabled && !followersEnabled {
                                    replyMode = .custom
                                }
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
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSettings()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func saveSettings() {
        // Build reply restriction based on selections
        let newRestriction: ReplyRestriction
        switch replyMode {
        case .everybody:
            newRestriction = .everybody
        case .nobody:
            newRestriction = .nobody
        case .custom:
            if mentionedEnabled && !followingEnabled && !followersEnabled {
                newRestriction = .mentioned
            } else if !mentionedEnabled && followingEnabled && !followersEnabled {
                newRestriction = .following
            } else if !mentionedEnabled && !followingEnabled && followersEnabled {
                newRestriction = .followers
            } else if mentionedEnabled || followingEnabled || followersEnabled {
                newRestriction = .combined(
                    mentioned: mentionedEnabled,
                    following: followingEnabled,
                    followers: followersEnabled
                )
            } else {
                newRestriction = .everybody
            }
        }

        settings = PostModerationSettings(
            allowQuotePosts: allowQuotePosts,
            replyRestriction: newRestriction
        )

        dismiss()
    }
}

// MARK: - Option Button

struct OptionButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? .blue : .primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.blue.opacity(0.15) : Color.secondary.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

// MARK: - Custom Option Button

struct CustomOptionButton: View {
    let title: String
    @Binding var isEnabled: Bool
    let isActive: Bool
    let onToggle: () -> Void

    var body: some View {
        Button {
            isEnabled.toggle()
            onToggle()
        } label: {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(isEnabled && isActive ? .blue : .primary)

                Spacer()

                if isEnabled && isActive {
                    Image(systemName: "checkmark")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background((isEnabled && isActive) ? Color.blue.opacity(0.15) : Color.secondary.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

#Preview {
    PostModerationSettingsView(settings: .constant(.default))
}
