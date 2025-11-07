//
//  AppTheme.swift
//  Skyscraper
//
//  Manages app-wide theme colors
//

import SwiftUI
import Combine

@MainActor
class AppTheme: ObservableObject {
    static let shared = AppTheme()

    @Published var accentColor: Color {
        didSet {
            saveColor()
        }
    }

    @Published var isCustomColor: Bool = false

    private init() {
        // Initialize with default first
        self.accentColor = ThemeColor.orange.color

        // Load saved color or keep default
        if let colorName = UserDefaults.standard.string(forKey: "accentColor") {
            if colorName == "custom" {
                // Load custom color from UserDefaults
                self.isCustomColor = true
                self.accentColor = loadCustomColor() ?? ThemeColor.orange.color
            } else if let color = ThemeColor.allCases.first(where: { $0.name == colorName }) {
                self.isCustomColor = false
                self.accentColor = color.color
            } else {
                self.isCustomColor = false
                self.accentColor = ThemeColor.orange.color
            }
        } else {
            self.isCustomColor = false
            self.accentColor = ThemeColor.orange.color
        }
    }

    private func saveColor() {
        if isCustomColor {
            // Save as custom color
            UserDefaults.standard.set("custom", forKey: "accentColor")
            saveCustomColor(accentColor)
        } else if let themeColor = ThemeColor.allCases.first(where: { $0.color == accentColor }) {
            // Save predefined color
            UserDefaults.standard.set(themeColor.name, forKey: "accentColor")
            // Clear custom color data
            UserDefaults.standard.removeObject(forKey: "customColorRed")
            UserDefaults.standard.removeObject(forKey: "customColorGreen")
            UserDefaults.standard.removeObject(forKey: "customColorBlue")
            UserDefaults.standard.removeObject(forKey: "customColorOpacity")
        }
    }

    func setCustomColor(_ color: Color) {
        isCustomColor = true
        accentColor = color
    }

    private func saveCustomColor(_ color: Color) {
        #if os(iOS)
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        UserDefaults.standard.set(Double(red), forKey: "customColorRed")
        UserDefaults.standard.set(Double(green), forKey: "customColorGreen")
        UserDefaults.standard.set(Double(blue), forKey: "customColorBlue")
        UserDefaults.standard.set(Double(alpha), forKey: "customColorOpacity")
        #endif
    }

    private func loadCustomColor() -> Color? {
        guard UserDefaults.standard.object(forKey: "customColorRed") != nil else {
            return nil
        }

        let red = UserDefaults.standard.double(forKey: "customColorRed")
        let green = UserDefaults.standard.double(forKey: "customColorGreen")
        let blue = UserDefaults.standard.double(forKey: "customColorBlue")
        let opacity = UserDefaults.standard.double(forKey: "customColorOpacity")

        return Color(red: red, green: green, blue: blue, opacity: opacity)
    }
}

enum ThemeColor: String, CaseIterable, Identifiable {
    case orange
    case blue
    case purple
    case pink
    case green
    case red
    case teal
    case indigo
    case yellow

    var id: String { rawValue }

    var name: String {
        rawValue.capitalized
    }

    var color: Color {
        switch self {
        case .orange: return .orange
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .green: return .green
        case .red: return .red
        case .teal: return .teal
        case .indigo: return .indigo
        case .yellow: return .yellow
        }
    }
}
