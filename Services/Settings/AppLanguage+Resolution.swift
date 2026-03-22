import Foundation

extension AppLanguage {
    static func resolve(from locale: Locale) -> AppLanguage {
        let identifier = locale.identifier.lowercased()

        if identifier.hasPrefix(AppLanguage.hebrew.rawValue) {
            return .hebrew
        }

        if identifier.hasPrefix(AppLanguage.russian.rawValue) {
            return .russian
        }

        return .english
    }
}

