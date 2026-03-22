import Foundation

enum RoutingTargetSource: String, Hashable, Codable, Sendable {
    case placeEntrance = "place_entrance"
    case routingPoint = "routing_point"
    case storedPreferred = "stored_preferred"
    case objectFallback = "object_fallback"

    var localizationKey: L10n.Key {
        switch self {
        case .placeEntrance:
            return .routingTargetSourcePlaceEntrance
        case .routingPoint:
            return .routingTargetSourceRoutingPoint
        case .storedPreferred:
            return .routingTargetSourceStoredPreferred
        case .objectFallback:
            return .routingTargetSourceObjectFallback
        }
    }
}

struct ResolvedRoutingTarget: Hashable, Codable, Sendable {
    let coordinate: GeoCoordinate
    let pointType: RoutingPointType
    let source: RoutingTargetSource
}

