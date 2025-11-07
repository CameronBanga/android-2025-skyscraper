//
//  FeedSelectorView.swift
//  Skyscraper
//
//  Feed selector with reordering and deletion support
//

import SwiftUI

struct FeedSelectorView: View {
    @ObservedObject var viewModel: TimelineViewModel
    @EnvironmentObject var theme: AppTheme
    @Binding var isPresented: Bool
    #if os(iOS)
    @Binding var editMode: EditMode

    init(viewModel: TimelineViewModel, isPresented: Binding<Bool>, editMode: Binding<EditMode>) {
        self.viewModel = viewModel
        self._isPresented = isPresented
        self._editMode = editMode
    }
    #else
    init(viewModel: TimelineViewModel, isPresented: Binding<Bool>) {
        self.viewModel = viewModel
        self._isPresented = isPresented
    }
    #endif

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.state.availableFeeds) { feed in
                    Button(action: {
                        // Only switch feed if not in edit mode
                        #if os(iOS)
                        if editMode == .inactive {
                            viewModel.switchToFeed(feed)
                            isPresented = false
                        }
                        #else
                        // macOS doesn't have edit mode, so always allow switching
                        viewModel.switchToFeed(feed)
                        isPresented = false
                        #endif
                    }) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(feed.displayName)
                                    .font(.body)
                                    .foregroundStyle(.primary)

                                if let description = feed.description {
                                    Text(description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }

                            Spacer()

                            if feed.id == viewModel.state.selectedFeed?.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(theme.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    // Disable deletion and reordering for system feeds (those without a URI)
                    .deleteDisabled(feed.uri == nil)
                    .moveDisabled(feed.uri == nil)
                }
                .onMove { source, destination in
                    viewModel.reorderFeeds(from: source, to: destination)
                }
                .onDelete { indexSet in
                    Task {
                        await viewModel.unfollowFeeds(at: indexSet)
                    }
                }
            }
            #if os(iOS)
            .environment(\.editMode, $editMode)
            #endif
            .navigationTitle("Feeds")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        #if os(iOS)
                        editMode = .inactive
                        #endif
                        isPresented = false
                    }
                }

                #if os(iOS)
                ToolbarItem(placement: .primaryAction) {
                    if editMode == .inactive {
                        Button("Edit") {
                            editMode = .active
                        }
                    }
                }
                #endif
            }
        }
        #if os(macOS)
        .frame(minWidth: 350, minHeight: 600)
        #else
        .frame(minWidth: 400, minHeight: 600)
        #endif
    }
}
