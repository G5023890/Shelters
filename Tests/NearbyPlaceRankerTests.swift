import Foundation
import XCTest
@testable import SheltersKit

final class NearbyPlaceRankerTests: XCTestCase {
    func testScorePrefersCloserActiveAccessiblePlace() {
        let ranker = NearbyPlaceRanker()
        let strongPlace = makePlace(
            confidence: 0.9,
            routingQuality: 0.8,
            isPublic: true,
            isAccessible: true,
            status: .active
        )
        let weakPlace = makePlace(
            confidence: 0.4,
            routingQuality: 0.3,
            isPublic: false,
            isAccessible: false,
            status: .temporarilyUnavailable
        )

        let strongScore = ranker.score(
            place: strongPlace,
            routingTarget: ResolvedRoutingTarget(
                coordinate: strongPlace.routingCoordinate,
                pointType: .entrance,
                source: .placeEntrance
            ),
            distanceMeters: 120,
            searchRadiusMeters: 5_000
        )

        let weakScore = ranker.score(
            place: weakPlace,
            routingTarget: ResolvedRoutingTarget(
                coordinate: weakPlace.routingCoordinate,
                pointType: .object,
                source: .objectFallback
            ),
            distanceMeters: 900,
            searchRadiusMeters: 5_000
        )

        XCTAssertGreaterThan(strongScore, weakScore)
    }

    func testInactivePlacesRankBelowActivePlacesWithSameSignals() {
        let ranker = NearbyPlaceRanker()
        let activePlace = makePlace(
            confidence: 0.7,
            routingQuality: 0.7,
            isPublic: true,
            isAccessible: true,
            status: .active
        )
        let inactivePlace = makePlace(
            confidence: 0.7,
            routingQuality: 0.7,
            isPublic: true,
            isAccessible: true,
            status: .inactive
        )

        let activeScore = ranker.score(
            place: activePlace,
            routingTarget: ResolvedRoutingTarget(
                coordinate: activePlace.routingCoordinate,
                pointType: .entrance,
                source: .placeEntrance
            ),
            distanceMeters: 250,
            searchRadiusMeters: 5_000
        )

        let inactiveScore = ranker.score(
            place: inactivePlace,
            routingTarget: ResolvedRoutingTarget(
                coordinate: inactivePlace.routingCoordinate,
                pointType: .entrance,
                source: .placeEntrance
            ),
            distanceMeters: 250,
            searchRadiusMeters: 5_000
        )

        XCTAssertGreaterThan(activeScore, inactiveScore)
    }

    private func makePlace(
        confidence: Double,
        routingQuality: Double,
        isPublic: Bool,
        isAccessible: Bool,
        status: PlaceStatus
    ) -> CanonicalPlace {
        CanonicalPlace(
            id: UUID(),
            name: LocalizedPlaceText(original: nil, english: "Place", russian: nil, hebrew: nil),
            address: LocalizedPlaceText(original: nil, english: "Address", russian: nil, hebrew: nil),
            city: "Tel Aviv",
            placeType: .publicShelter,
            objectCoordinate: GeoCoordinate(latitude: 32.1, longitude: 34.8),
            entranceCoordinate: GeoCoordinate(latitude: 32.1002, longitude: 34.8002),
            preferredRoutingCoordinate: GeoCoordinate(latitude: 32.1002, longitude: 34.8002),
            preferredRoutingPointType: .entrance,
            isPublic: isPublic,
            isAccessible: isAccessible,
            status: status,
            confidenceScore: confidence,
            routingQuality: routingQuality,
            lastVerifiedAt: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
