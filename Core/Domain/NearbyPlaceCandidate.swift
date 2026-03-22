import Foundation

struct NearbyPlaceCandidate: Identifiable, Hashable, Sendable {
    let id: UUID
    let place: CanonicalPlace
    let routingTarget: ResolvedRoutingTarget
    let distanceMeters: Double
    let estimatedWalkingMinutes: Int
    let rankingScore: Double
}
