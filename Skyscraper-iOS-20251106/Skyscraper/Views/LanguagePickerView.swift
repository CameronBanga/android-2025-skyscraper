//
//  LanguagePickerView.swift
//  Skyscraper
//
//  Language selection for post composition
//

import SwiftUI

struct LanguagePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedLanguage: Language
    @State private var searchText = ""

    private var filteredLanguages: [Language] {
        if searchText.isEmpty {
            return Language.allLanguages
        } else {
            return Language.allLanguages.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    ForEach(filteredLanguages) { language in
                        Button {
                            selectedLanguage = language
                            LanguagePreferences.shared.preferredLanguage = language
                            dismiss()
                        } label: {
                            HStack {
                                Text(language.name)
                                    .foregroundStyle(.primary)

                                Spacer()

                                if language.id == selectedLanguage.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .id(language.id)
                    }
                }
                .searchable(text: $searchText, prompt: "Search languages")
                .onAppear {
                    // Scroll to selected language when view appears
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        proxy.scrollTo(selectedLanguage.id, anchor: .top)
                    }
                }
            }
            .navigationTitle("Post Language")
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
    }
}

#Preview {
    LanguagePickerView(selectedLanguage: .constant(Language.defaultLanguage))
}
