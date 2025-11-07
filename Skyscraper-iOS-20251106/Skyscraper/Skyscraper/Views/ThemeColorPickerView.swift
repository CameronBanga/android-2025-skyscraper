//
//  ThemeColorPickerView.swift
//  Skyscraper
//
//  Color theme picker for app accent color
//

import SwiftUI

struct ThemeColorPickerView: View {
    @EnvironmentObject var theme: AppTheme
    @Environment(\.dismiss) var dismiss
    @State private var customColor: Color = .blue
    @State private var showingColorPicker = false

    var body: some View {
        List {
            Section {
                ForEach(ThemeColor.allCases) { themeColor in
                    Button {
                        theme.isCustomColor = false
                        theme.accentColor = themeColor.color

                        // Track accent color change
                        Analytics.logEvent("user_changed_accent_color", parameters: [
                            "color_name": themeColor.name
                        ])
                        print("📊 Analytics: Logged user_changed_accent_color (\(themeColor.name))")
                    } label: {
                        HStack(spacing: 12) {
                            // Color circle
                            Circle()
                                .fill(themeColor.color)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .strokeBorder(.gray.opacity(0.2), lineWidth: 1)
                                )

                            // Color name
                            Text(themeColor.name)
                                .font(.body)
                                .foregroundStyle(.primary)

                            Spacer()

                            // Checkmark for selected color
                            if !theme.isCustomColor && theme.accentColor == themeColor.color {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(themeColor.color)
                                    .fontWeight(.semibold)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            } header: {
                Text("Preset Colors")
            }

            Section {
                // Custom Color selector button - always opens color picker
                Button {
                    showingColorPicker = true
                } label: {
                    HStack(spacing: 12) {
                        // Color circle
                        Circle()
                            .fill(theme.isCustomColor ? theme.accentColor : customColor)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle()
                                    .strokeBorder(.gray.opacity(0.2), lineWidth: 1)
                            )

                        // Color name
                        Text("Custom Color")
                            .font(.body)
                            .foregroundStyle(.primary)

                        Spacer()

                        // Checkmark for selected custom color
                        if theme.isCustomColor {
                            Image(systemName: "checkmark")
                                .foregroundStyle(theme.accentColor)
                                .fontWeight(.semibold)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            } header: {
                Text("Custom")
            }
        }
        .navigationTitle("Accent Color")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showingColorPicker) {
            NavigationStack {
                VStack(spacing: 24) {
                    // Large color preview
                    Circle()
                        .fill(customColor)
                        .frame(width: 100, height: 100)
                        .overlay(
                            Circle()
                                .strokeBorder(.gray.opacity(0.3), lineWidth: 2)
                        )
                        .shadow(color: customColor.opacity(0.3), radius: 10)
                        .padding(.top, 32)

                    // Color picker with default appearance
                    ColorPicker("Color Picker", selection: $customColor, supportsOpacity: false)
                        .padding(.horizontal, 32)
                        .padding(.top, 16)

                    Spacer()
                }
                .navigationTitle("Custom Color")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingColorPicker = false
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            theme.setCustomColor(customColor)

                            // Track custom color change
                            Analytics.logEvent("user_changed_accent_color", parameters: [
                                "color_name": "custom"
                            ])
                            print("📊 Analytics: Logged user_changed_accent_color (custom)")

                            showingColorPicker = false
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .onAppear {
            // Initialize custom color with current theme color if it's custom
            if theme.isCustomColor {
                customColor = theme.accentColor
            }
        }
    }
}

#Preview {
    NavigationStack {
        ThemeColorPickerView()
            .environmentObject(AppTheme.shared)
    }
}
