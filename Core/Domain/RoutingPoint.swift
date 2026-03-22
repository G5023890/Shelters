import Foundation

struct RoutingPoint: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let canonicalPlaceID: UUID
    let coordinate: GeoCoordinate
    let pointType: RoutingPointType
    let confidence: Double
    let derivedFrom: String?
    let createdAt: Date
}

