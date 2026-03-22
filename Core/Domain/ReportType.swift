import Foundation

enum ReportType: String, CaseIterable, Codable, Sendable, Identifiable {
    case wrongLocation = "wrong_location"
    case confirmLocation = "confirm_location"
    case movedEntrance = "moved_entrance"
    case newPlace = "new_place"
    case photoEvidence = "photo_evidence"

    var id: String { rawValue }

    var systemImageName: String {
        switch self {
        case .wrongLocation:
            return "location.slash"
        case .confirmLocation:
            return "checkmark.seal"
        case .movedEntrance:
            return "arrow.triangle.branch"
        case .newPlace:
            return "plus.circle"
        case .photoEvidence:
            return "photo"
        }
    }

    var localizationKey: L10n.Key {
        switch self {
        case .wrongLocation:
            return .reportTypeWrongLocation
        case .confirmLocation:
            return .reportTypeConfirmLocation
        case .movedEntrance:
            return .reportTypeMovedEntrance
        case .newPlace:
            return .reportTypeNewPlace
        case .photoEvidence:
            return .reportTypePhotoEvidence
        }
    }
}
