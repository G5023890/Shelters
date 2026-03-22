import Foundation

enum AppLanguage: String, CaseIterable, Codable, Sendable, Identifiable {
    case english = "en"
    case russian = "ru"
    case hebrew = "he"

    var id: String { rawValue }

    var localeIdentifier: String { rawValue }

    var settingsLocalizationKey: L10n.Key {
        switch self {
        case .english:
            return .languageEnglish
        case .russian:
            return .languageRussian
        case .hebrew:
            return .languageHebrew
        }
    }
}

