import Foundation

enum ShelterAccessPolicy {
    static let maxEmergencyWalkingMinutes = 8
    static let defaultPreviewCity = "Petah Tikva"

    static var maxEmergencyWalkingDistanceMeters: Double {
        DistanceCalculator.distanceMeters(forEstimatedWalkingMinutes: maxEmergencyWalkingMinutes)
    }

    static func isWithinEmergencyWalkingWindow(distanceMeters: Double) -> Bool {
        DistanceCalculator.estimatedWalkingMinutes(forMeters: distanceMeters) <= maxEmergencyWalkingMinutes
    }
}
