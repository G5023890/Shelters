import Foundation

enum PlaceStatus: String, CaseIterable, Codable, Sendable {
    case active
    case inactive
    case unverified
    case temporarilyUnavailable = "temporarily_unavailable"
    case removed

    var localizationKey: L10n.Key {
        switch self {
        case .active:
            return .placeStatusActive
        case .inactive:
            return .placeStatusInactive
        case .unverified:
            return .placeStatusUnverified
        case .temporarilyUnavailable:
            return .placeStatusTemporarilyUnavailable
        case .removed:
            return .placeStatusRemoved
        }
    }
}
