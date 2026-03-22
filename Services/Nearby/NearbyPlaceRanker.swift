import Foundation

struct NearbyPlaceRanker: Sendable {
    func score(
        place: CanonicalPlace,
        routingTarget: ResolvedRoutingTarget,
        distanceMeters: Double,
        searchRadiusMeters: Double
    ) -> Double {
        let normalizedDistance = min(distanceMeters / max(searchRadiusMeters, 1), 1)
        let distanceComponent = (1 - normalizedDistance) * 0.5
        let confidenceComponent = clamped(place.confidenceScore) * 0.18
        let routingQualityComponent = clamped(place.routingQuality) * 0.14
        let accessibilityComponent = place.isAccessible ? 0.05 : 0
        let publicAccessComponent = place.isPublic ? 0.04 : 0
        let statusComponent = statusBonus(for: place.status)
        let routingTargetComponent = routingTargetBonus(for: routingTarget)

        return distanceComponent
            + confidenceComponent
            + routingQualityComponent
            + accessibilityComponent
            + publicAccessComponent
            + statusComponent
            + routingTargetComponent
    }

    private func routingTargetBonus(for routingTarget: ResolvedRoutingTarget) -> Double {
        switch routingTarget.source {
        case .placeEntrance:
            return 0.06
        case .routingPoint:
            return 0.04
        case .storedPreferred:
            return 0.02
        case .objectFallback:
            return 0
        }
    }

    private func statusBonus(for status: PlaceStatus) -> Double {
        switch status {
        case .active:
            return 0.03
        case .inactive:
            return -0.12
        case .unverified:
            return 0.01
        case .temporarilyUnavailable:
            return -0.08
        case .removed:
            return -1
        }
    }

    private func clamped(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
