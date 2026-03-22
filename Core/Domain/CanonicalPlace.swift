import Foundation

struct CanonicalPlace: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let name: LocalizedPlaceText
    let address: LocalizedPlaceText
    let city: String?
    let placeType: PlaceType
    let objectCoordinate: GeoCoordinate
    let entranceCoordinate: GeoCoordinate?
    let preferredRoutingCoordinate: GeoCoordinate?
    let preferredRoutingPointType: RoutingPointType?
    let isPublic: Bool
    let isAccessible: Bool
    let status: PlaceStatus
    let confidenceScore: Double
    let routingQuality: Double
    let lastVerifiedAt: Date?
    let createdAt: Date
    let updatedAt: Date

    var routingCoordinate: GeoCoordinate {
        entranceCoordinate ?? preferredRoutingCoordinate ?? objectCoordinate
    }

    var fallbackRoutingTarget: ResolvedRoutingTarget {
        if let entranceCoordinate {
            return ResolvedRoutingTarget(
                coordinate: entranceCoordinate,
                pointType: .entrance,
                source: .placeEntrance
            )
        }

        if let preferredRoutingCoordinate {
            return ResolvedRoutingTarget(
                coordinate: preferredRoutingCoordinate,
                pointType: preferredRoutingPointType ?? .preferred,
                source: .storedPreferred
            )
        }

        return ResolvedRoutingTarget(
            coordinate: objectCoordinate,
            pointType: .object,
            source: .objectFallback
        )
    }

    func displayName(for language: AppLanguage) -> String {
        name.bestValue(for: language)
    }

    func displayAddress(for language: AppLanguage) -> String {
        address.bestValue(for: language)
    }
}
