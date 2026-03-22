import Foundation

enum LocationAuthorizationStatus: Equatable, Sendable {
    case notDetermined
    case denied
    case restricted
    case authorized
}

struct LocationSnapshot: Hashable, Sendable {
    let coordinate: GeoCoordinate
    let timestamp: Date
}

@MainActor
protocol LocationService: Sendable {
    func authorizationStatus() async -> LocationAuthorizationStatus
    func requestPermission() async -> LocationAuthorizationStatus
    func currentLocation() async throws -> LocationSnapshot?
    func locationUpdates() -> AsyncThrowingStream<LocationSnapshot, Error>
}
