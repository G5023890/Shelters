import Foundation

enum RoutingPointType: String, CaseIterable, Codable, Sendable {
    case entrance
    case preferred
    case object
    case inferred
    case userSubmitted = "user_submitted"

    var localizationKey: L10n.Key {
        switch self {
        case .entrance:
            return .routingPointTypeEntrance
        case .preferred:
            return .routingPointTypePreferred
        case .object:
            return .routingPointTypeObject
        case .inferred:
            return .routingPointTypeInferred
        case .userSubmitted:
            return .routingPointTypeUserSubmitted
        }
    }
}
