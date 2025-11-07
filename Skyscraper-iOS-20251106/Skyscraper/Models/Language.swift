//
//  Language.swift
//  Skyscraper
//
//  ISO 639-1 language codes for post composition
//

import Foundation

struct Language: Identifiable, Codable, Equatable {
    let id: String // ISO 639-1 code
    let name: String

    static let allLanguages: [Language] = [
        Language(id: "en", name: "English"),
        Language(id: "es", name: "Spanish"),
        Language(id: "fr", name: "French"),
        Language(id: "de", name: "German"),
        Language(id: "it", name: "Italian"),
        Language(id: "pt", name: "Portuguese"),
        Language(id: "nl", name: "Dutch"),
        Language(id: "pl", name: "Polish"),
        Language(id: "ru", name: "Russian"),
        Language(id: "ja", name: "Japanese"),
        Language(id: "ko", name: "Korean"),
        Language(id: "zh", name: "Chinese"),
        Language(id: "ar", name: "Arabic"),
        Language(id: "hi", name: "Hindi"),
        Language(id: "bn", name: "Bengali"),
        Language(id: "pa", name: "Punjabi"),
        Language(id: "te", name: "Telugu"),
        Language(id: "mr", name: "Marathi"),
        Language(id: "ta", name: "Tamil"),
        Language(id: "ur", name: "Urdu"),
        Language(id: "tr", name: "Turkish"),
        Language(id: "vi", name: "Vietnamese"),
        Language(id: "th", name: "Thai"),
        Language(id: "id", name: "Indonesian"),
        Language(id: "ms", name: "Malay"),
        Language(id: "fil", name: "Filipino"),
        Language(id: "sv", name: "Swedish"),
        Language(id: "no", name: "Norwegian"),
        Language(id: "da", name: "Danish"),
        Language(id: "fi", name: "Finnish"),
        Language(id: "cs", name: "Czech"),
        Language(id: "sk", name: "Slovak"),
        Language(id: "hu", name: "Hungarian"),
        Language(id: "ro", name: "Romanian"),
        Language(id: "bg", name: "Bulgarian"),
        Language(id: "hr", name: "Croatian"),
        Language(id: "sr", name: "Serbian"),
        Language(id: "uk", name: "Ukrainian"),
        Language(id: "el", name: "Greek"),
        Language(id: "he", name: "Hebrew"),
        Language(id: "fa", name: "Persian"),
        Language(id: "sw", name: "Swahili"),
        Language(id: "af", name: "Afrikaans"),
        Language(id: "am", name: "Amharic"),
        Language(id: "ca", name: "Catalan"),
        Language(id: "eu", name: "Basque"),
        Language(id: "gl", name: "Galician"),
        Language(id: "cy", name: "Welsh"),
        Language(id: "ga", name: "Irish"),
        Language(id: "is", name: "Icelandic"),
        Language(id: "lt", name: "Lithuanian"),
        Language(id: "lv", name: "Latvian"),
        Language(id: "et", name: "Estonian"),
        Language(id: "mt", name: "Maltese"),
        Language(id: "sq", name: "Albanian"),
        Language(id: "mk", name: "Macedonian"),
        Language(id: "sl", name: "Slovenian"),
        Language(id: "bs", name: "Bosnian")
    ].sorted { $0.name < $1.name }

    static let defaultLanguage = Language(id: "en", name: "English")
}

class LanguagePreferences {
    static let shared = LanguagePreferences()
    private let defaults = UserDefaults.standard
    private let languageKey = "preferredPostLanguage"

    var preferredLanguage: Language {
        get {
            if let data = defaults.data(forKey: languageKey),
               let language = try? JSONDecoder().decode(Language.self, from: data) {
                return language
            }
            return Language.defaultLanguage
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: languageKey)
            }
        }
    }
}
