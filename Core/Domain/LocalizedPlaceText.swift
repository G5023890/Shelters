import Foundation

struct LocalizedPlaceText: Hashable, Codable, Sendable {
    let original: String?
    let english: String?
    let russian: String?
    let hebrew: String?

    func bestValue(for language: AppLanguage) -> String {
        value(for: language) ?? english ?? original ?? russian ?? hebrew ?? ""
    }

    func value(for language: AppLanguage) -> String? {
        switch language {
        case .english:
            return english
        case .russian:
            return russian
        case .hebrew:
            return hebrew
        }
    }
}

