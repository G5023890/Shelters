import Foundation

protocol NearbySearchService: Sendable {
    func searchNearby(from coordinate: GeoCoordinate, radiusMeters: Double, limit: Int) async throws -> [NearbyPlaceCandidate]
    func recentPlaces(limit: Int) async throws -> [CanonicalPlace]
}

