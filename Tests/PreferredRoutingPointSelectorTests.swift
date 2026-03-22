import Foundation
import XCTest
@testable import SheltersKit

final class PreferredRoutingPointSelectorTests: XCTestCase {
    func testSelectorUsesEntranceCoordinateBeforeOtherRoutingPoints() {
        let place = CanonicalPlace(
            id: UUID(),
            name: LocalizedPlaceText(original: nil, english: "Shelter", russian: nil, hebrew: nil),
            address: LocalizedPlaceText(original: nil, english: "1 Example St", russian: nil, hebrew: nil),
            city: "Haifa",
            placeType: .publicShelter,
            objectCoordinate: GeoCoordinate(latitude: 32.8, longitude: 35.0),
            entranceCoordinate: GeoCoordinate(latitude: 32.8004, longitude: 35.0004),
            preferredRoutingCoordinate: GeoCoordinate(latitude: 32.8001, longitude: 35.0001),
            preferredRoutingPointType: .preferred,
            isPublic: true,
            isAccessible: true,
            status: .active,
            confidenceScore: 0.9,
            routingQuality: 0.8,
            lastVerifiedAt: nil,
            createdAt: Date(),
            updatedAt: Date()
        )

        let routingPoint = RoutingPoint(
            id: UUID(),
            canonicalPlaceID: place.id,
            coordinate: GeoCoordinate(latitude: 32.801, longitude: 35.001),
            pointType: .preferred,
            confidence: 0.95,
            derivedFrom: nil,
            createdAt: Date()
        )

        let resolvedTarget = PreferredRoutingPointSelector().resolve(for: place, routingPoints: [routingPoint])

        XCTAssertEqual(resolvedTarget.coordinate.latitude, 32.8004, accuracy: 0.00001)
        XCTAssertEqual(resolvedTarget.pointType, .entrance)
        XCTAssertEqual(resolvedTarget.source, .placeEntrance)
    }
}
