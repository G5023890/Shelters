import Foundation

enum SearchTileKey {
    static func make(for coordinate: GeoCoordinate, precision: Double = 0.05) -> String {
        let latBucket = Int(floor(coordinate.latitude / precision))
        let lonBucket = Int(floor(coordinate.longitude / precision))
        return "\(latBucket)_\(lonBucket)"
    }

    static func neighborhoodKeys(
        around coordinate: GeoCoordinate,
        radiusMeters: Double,
        precision: Double = 0.05
    ) -> [String] {
        let bounds = DistanceCalculator.searchBounds(around: coordinate, radiusMeters: radiusMeters)
        let minLatBucket = Int(floor(bounds.minLatitude / precision))
        let maxLatBucket = Int(floor(bounds.maxLatitude / precision))
        let minLonBucket = Int(floor(bounds.minLongitude / precision))
        let maxLonBucket = Int(floor(bounds.maxLongitude / precision))

        var keys: [String] = []

        for latBucket in minLatBucket...maxLatBucket {
            for lonBucket in minLonBucket...maxLonBucket {
                keys.append("\(latBucket)_\(lonBucket)")
            }
        }

        return keys
    }
}
