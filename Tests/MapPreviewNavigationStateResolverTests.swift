import Foundation
import XCTest
@testable import SheltersKit

final class MapPreviewNavigationStateResolverTests: XCTestCase {
    func testVisibleCandidatesKeepPinnedActiveRouteFirst() {
        let candidates = [
            makeCandidate(id: "route-1", distanceMeters: 150, travelTime: 60),
            makeCandidate(id: "route-2", distanceMeters: 120, travelTime: 50),
            makeCandidate(id: "route-3", distanceMeters: 180, travelTime: 70),
            makeCandidate(id: "route-4", distanceMeters: 240, travelTime: 90)
        ]

        let visible = MapPreviewNavigationStateResolver.visibleCandidates(
            sortedCandidates: candidates,
            activeRouteCandidateID: "route-3"
        )

        XCTAssertEqual(visible.map(\.id), ["route-3", "route-1", "route-2"])
    }

    func testNextActiveRouteKeepsCurrentSelectionWhenStillVisible() {
        let visible = [
            makeCandidate(id: "route-2", distanceMeters: 120, travelTime: 50),
            makeCandidate(id: "route-1", distanceMeters: 150, travelTime: 60),
            makeCandidate(id: "route-4", distanceMeters: 240, travelTime: 90)
        ]

        let nextID = MapPreviewNavigationStateResolver.nextActiveRouteCandidateID(
            currentActiveRouteCandidateID: "route-4",
            visibleCandidates: visible,
            preserveCurrentSelection: true
        )

        XCTAssertEqual(nextID, "route-4")
    }

    func testPhaseBecomesArrivedWithinThreshold() {
        let phase = MapPreviewNavigationStateResolver.phase(
            remainingDistanceMeters: 18,
            arrivalThresholdMeters: 35
        )

        XCTAssertEqual(phase, .arrived)
    }

    func testRouteClusterWarningAppearsWhenLocalCityHasTooFewCandidates() {
        let warning = MapPreviewNavigationStateResolver.routeClusterWarning(
            localCity: "Petah Tikva",
            localCandidateCount: 1,
            requestedCandidateCount: 3,
            language: .english
        )

        XCTAssertEqual(
            warning,
            "Only 1 shelter option(s) were found in Petah Tikva. Remaining alternatives are shown from nearby cities."
        )
    }

    private func makeCandidate(
        id: String,
        distanceMeters: Double,
        travelTime: TimeInterval?
    ) -> MapRouteCandidate {
        let place = CanonicalPlace(
            id: UUID(),
            name: LocalizedPlaceText(original: nil, english: id, russian: id, hebrew: id),
            address: LocalizedPlaceText(original: nil, english: "1 Main St", russian: nil, hebrew: nil),
            city: "Tel Aviv",
            placeType: .publicShelter,
            objectCoordinate: GeoCoordinate(latitude: 32.08, longitude: 34.78),
            entranceCoordinate: GeoCoordinate(latitude: 32.0801, longitude: 34.7801),
            preferredRoutingCoordinate: nil,
            preferredRoutingPointType: nil,
            isPublic: true,
            isAccessible: true,
            status: .active,
            confidenceScore: 0.9,
            routingQuality: 0.9,
            lastVerifiedAt: nil,
            createdAt: Date(),
            updatedAt: Date()
        )

        let target = MapRouteTargetOption(
            id: "target-\(id)",
            coordinate: GeoCoordinate(latitude: 32.0802, longitude: 34.7802),
            pointType: .entrance,
            source: .placeEntrance
        )

        return MapRouteCandidate(
            id: id,
            place: place,
            target: target,
            availableTargets: [target],
            summary: MapRouteSummary(distanceMeters: distanceMeters, expectedTravelTime: travelTime),
            lineKind: .turnByTurn,
            polylineCoordinates: [],
            directDistanceMeters: distanceMeters
        )
    }
}
