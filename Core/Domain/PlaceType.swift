import Foundation

enum PlaceType: String, CaseIterable, Codable, Sendable {
    case publicShelter = "public_shelter"
    case migunit = "migunit"
    case protectedParking = "protected_parking"
    case underground = "underground"
    case other = "other"

    var localizationKey: L10n.Key {
        switch self {
        case .publicShelter:
            return .placeTypePublicShelter
        case .migunit:
            return .placeTypeMigunit
        case .protectedParking:
            return .placeTypeProtectedParking
        case .underground:
            return .placeTypeUnderground
        case .other:
            return .placeTypeOther
        }
    }
}

