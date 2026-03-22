import Foundation
import XCTest
@testable import SheltersKit

final class PlaceDetailsPresentationTests: XCTestCase {
    func testPresentationUsesSelectedLanguageAndTrustMetadata() {
        let place = CanonicalPlace(
            id: UUID(uuidString: "5F8EE247-C53B-46B0-B0C8-A39552C8A501")!,
            name: LocalizedPlaceText(
                original: "מקלט העיר",
                english: "City Shelter",
                russian: "Городское укрытие",
                hebrew: "מקלט העיר"
            ),
            address: LocalizedPlaceText(
                original: "רחוב הראשי 10",
                english: "10 Main Street",
                russian: "улица Мейн, 10",
                hebrew: "רחוב הראשי 10"
            ),
            city: "Beer Sheva",
            placeType: .publicShelter,
            objectCoordinate: GeoCoordinate(latitude: 31.2589, longitude: 34.8081),
            entranceCoordinate: GeoCoordinate(latitude: 31.2590, longitude: 34.8082),
            preferredRoutingCoordinate: GeoCoordinate(latitude: 31.2590, longitude: 34.8082),
            preferredRoutingPointType: .entrance,
            isPublic: true,
            isAccessible: false,
            status: .active,
            confidenceScore: 0.93,
            routingQuality: 0.84,
            lastVerifiedAt: Date(timeIntervalSince1970: 1_741_760_000),
            createdAt: Date(timeIntervalSince1970: 1_741_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_741_760_000)
        )

        let presentation = PlaceDetailsPresentationBuilder.make(
            place: place,
            language: .russian,
            distanceMeters: 420,
            syncStatus: SyncStatusSnapshot.initial.updating(
                installedDatasetVersion: .replace("beer-sheva-canonical-v1-20260308T011024Z"),
                lastSuccessfulSyncAt: .replace(Date(timeIntervalSince1970: 1_741_800_000))
            ),
            sourceAttributions: [
                PlaceSourceAttribution(
                    id: UUID(uuidString: "2AAE9397-B84D-4E48-93C1-9270F8320001")!,
                    canonicalPlaceID: place.id,
                    sourceName: "beer-sheva-municipal-shelters",
                    sourceIdentifier: "source-1",
                    importedAt: Date()
                ),
                PlaceSourceAttribution(
                    id: UUID(uuidString: "2AAE9397-B84D-4E48-93C1-9270F8320002")!,
                    canonicalPlaceID: place.id,
                    sourceName: "beer-sheva-municipal-shelters-itm",
                    sourceIdentifier: "source-2",
                    importedAt: Date()
                )
            ],
            routingTarget: place.fallbackRoutingTarget
        )

        XCTAssertEqual(presentation.title, "Городское укрытие")
        XCTAssertEqual(presentation.addressText, "улица Мейн, 10")
        XCTAssertEqual(presentation.distanceText, "420 м")
        XCTAssertEqual(presentation.verificationLevel, .high)
        XCTAssertEqual(presentation.entranceAvailabilityText, L10n.string(.placeDetailsEntranceAvailable, language: .russian))
        XCTAssertEqual(presentation.routingPointSummaryText, L10n.string(.routingTargetSourcePlaceEntrance, language: .russian))
        XCTAssertTrue(presentation.sourceCoverageText?.contains("2") == true)
        XCTAssertEqual(presentation.installedDatasetVersionText, "beer-sheva-canonical-v1-20260308T011024Z")
    }

    func testPresentationMarksUnverifiedLowConfidencePlacesClearly() {
        let place = CanonicalPlace(
            id: UUID(uuidString: "8C779325-F03F-4452-B1A0-2EBB4A9EF411")!,
            name: LocalizedPlaceText(original: "Fallback Shelter", english: "Fallback Shelter", russian: nil, hebrew: nil),
            address: LocalizedPlaceText(original: nil, english: nil, russian: nil, hebrew: nil),
            city: nil,
            placeType: .other,
            objectCoordinate: GeoCoordinate(latitude: 32.08, longitude: 34.78),
            entranceCoordinate: nil,
            preferredRoutingCoordinate: GeoCoordinate(latitude: 32.08, longitude: 34.78),
            preferredRoutingPointType: .object,
            isPublic: true,
            isAccessible: false,
            status: .unverified,
            confidenceScore: 0.41,
            routingQuality: 0.48,
            lastVerifiedAt: nil,
            createdAt: Date(timeIntervalSince1970: 1_741_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_741_760_000)
        )

        let presentation = PlaceDetailsPresentationBuilder.make(
            place: place,
            language: .english,
            distanceMeters: nil,
            syncStatus: nil,
            sourceAttributions: [],
            routingTarget: place.fallbackRoutingTarget
        )

        XCTAssertEqual(presentation.verificationLevel, .low)
        XCTAssertEqual(presentation.routingQualityText, L10n.string(.placeDetailsRoutingQualityLimited))
        XCTAssertNil(presentation.sourceCoverageText)
        XCTAssertNil(presentation.addressText)
    }
}
