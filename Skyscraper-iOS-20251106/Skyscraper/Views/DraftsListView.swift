//
//  DraftsListView.swift
//  Skyscraper
//
//  View for displaying saved draft posts
//

import SwiftUI

struct DraftsListView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var theme: AppTheme
    @ObservedObject private var draftManager = DraftManager.shared

    let onSelectDraft: (PostDraft) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                if draftManager.drafts.isEmpty {
                    emptyView
                } else {
                    List {
                        ForEach(draftManager.drafts) { draft in
                            Button(action: {
                                onSelectDraft(draft)
                                dismiss()
                            }) {
                                DraftCell(draft: draft)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button("Delete", role: .destructive) {
                                    withAnimation {
                                        draftManager.deleteDraft(draft)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Drafts")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .tint(theme.accentColor)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No Drafts")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Drafts you save will appear here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct DraftCell: View {
    let draft: PostDraft
    @EnvironmentObject var theme: AppTheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(draft.preview)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(3)

                HStack(spacing: 8) {
                    if !draft.imageData.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "photo")
                                .font(.caption)
                            Text("\(draft.imageData.count)")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }

                    Text(draft.relativeTime)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    DraftsListView { _ in }
        .environmentObject(AppTheme.shared)
}
