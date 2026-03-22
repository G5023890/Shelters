import Foundation

enum DistanceCalculator {
    static let walkingMetersPerMinute = 80.0

    struct SearchBounds: Hashable, Sendable {
        let minLatitude: Double
        let maxLatitude: Double
        let minLongitude: Double
        let maxLongitude: Double
    }

    static func meters(from origin: GeoCoordinate, to destination: GeoCoordinate) -> Double {
        let earthRadius = 6_371_000.0
        let originLatitude = origin.latitude * .pi / 180
        let destinationLatitude = destination.latitude * .pi / 180
        let latitudeDelta = (destination.latitude - origin.latitude) * .pi / 180
        let longitudeDelta = (destination.longitude - origin.longitude) * .pi / 180

        let a = sin(latitudeDelta / 2) * sin(latitudeDelta / 2)
            + cos(originLatitude) * cos(destinationLatitude)
            * sin(longitudeDelta / 2) * sin(longitudeDelta / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))

        return earthRadius * c
    }

    static func searchBounds(around center: GeoCoordinate, radiusMeters: Double) -> SearchBounds {
        let latitudeDelta = radiusMeters / 111_000
        let cosLatitude = max(abs(cos(center.latitude * .pi / 180)), 0.01)
        let longitudeDelta = radiusMeters / (111_000 * cosLatitude)

        return SearchBounds(
            minLatitude: center.latitude - latitudeDelta,
            maxLatitude: center.latitude + latitudeDelta,
            minLongitude: center.longitude - longitudeDelta,
            maxLongitude: center.longitude + longitudeDelta
        )
    }

    static func estimatedWalkingMinutes(forMeters meters: Double) -> Int {
        return max(1, Int((meters / walkingMetersPerMinute).rounded()))
    }

    static func distanceMeters(forEstimatedWalkingMinutes minutes: Int) -> Double {
        max(0, Double(minutes)) * walkingMetersPerMinute
    }
}
