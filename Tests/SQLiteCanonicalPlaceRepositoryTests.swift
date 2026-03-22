import Foundation
import XCTest
@testable import SheltersKit

final class SQLiteCanonicalPlaceRepositoryTests: XCTestCase {
    func testUpsertAndNearbyLookupUsePreferredRoutingCoordinate() throws {
        let database = try SQLiteDatabase.inMemory()
        try DatabaseMigrator().migrate(database)

        let repository = SQLiteCanonicalPlaceRepository(database: database)
        let place = CanonicalPlace(
            id: UUID(),
            name: LocalizedPlaceText(
                original: "מקלט",
                english: "Shelter 1",
                russian: "Укрытие 1",
                hebrew: "מקלט 1"
            ),
            address: LocalizedPlaceText(
                original: "Original address",
                english: "1 Example Street",
                russian: "Примерная улица 1",
                hebrew: "רחוב לדוגמה 1"
            ),
            city: "Tel Aviv",
            placeType: .publicShelter,
            objectCoordinate: GeoCoordinate(latitude: 32.0840, longitude: 34.7818),
            entranceCoordinate: GeoCoordinate(latitude: 32.0842, longitude: 34.7820),
            preferredRoutingCoordinate: GeoCoordinate(latitude: 32.0842, longitude: 34.7820),
            preferredRoutingPointType: .entrance,
            isPublic: true,
            isAccessible: true,
            status: .active,
            confidenceScore: 0.9,
            routingQuality: 0.8,
            lastVerifiedAt: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )

        try repository.upsert([place])

        let results = try repository.fetchNearbyCandidates(
            around: GeoCoordinate(latitude: 32.0841, longitude: 34.7819),
            radiusMeters: 500,
            limit: 10
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.id, place.id)
        XCTAssertEqual(try repository.count(), 1)
    }

    func testUpsertPersistsEntranceCoordinateAsPreferredSearchCoordinateWhenAvailable() throws {
        let database = try SQLiteDatabase.inMemory()
        try DatabaseMigrator().migrate(database)

        let repository = SQLiteCanonicalPlaceRepository(database: database)
        let place = CanonicalPlace(
            id: UUID(),
            name: LocalizedPlaceText(original: nil, english: "Shelter 2", russian: nil, hebrew: nil),
            address: LocalizedPlaceText(original: nil, english: "2 Example Street", russian: nil, hebrew: nil),
            city: "Ashdod",
            placeType: .publicShelter,
            objectCoordinate: GeoCoordinate(latitude: 31.8010, longitude: 34.6430),
            entranceCoordinate: GeoCoordinate(latitude: 31.8018, longitude: 34.6438),
            preferredRoutingCoordinate: GeoCoordinate(latitude: 31.8090, longitude: 34.6500),
            preferredRoutingPointType: .preferred,
            isPublic: true,
            isAccessible: false,
            status: .active,
            confidenceScore: 0.8,
            routingQuality: 0.7,
            lastVerifiedAt: nil,
            createdAt: Date(),
            updatedAt: Date()
        )

        try repository.upsert([place])

        let row = try database.query(
            "SELECT preferred_routing_lat, preferred_routing_lon FROM canonical_places WHERE id = ? LIMIT 1;",
            bindings: [.text(place.id.uuidString)]
        ).first

        let persistedLatitude = try XCTUnwrap(row?.double("preferred_routing_lat"))
        let persistedLongitude = try XCTUnwrap(row?.double("preferred_routing_lon"))
        let entranceCoordinate = try XCTUnwrap(place.entranceCoordinate)

        XCTAssertEqual(persistedLatitude, entranceCoordinate.latitude, accuracy: 0.000001)
        XCTAssertEqual(persistedLongitude, entranceCoordinate.longitude, accuracy: 0.000001)
    }

    func testFetchMatchesCanonicalPlaceIDCaseInsensitivelyForPublishedDatasets() throws {
        let database = try SQLiteDatabase.inMemory()
        try DatabaseMigrator().migrate(database)

        let placeID = UUID(uuidString: "0f4e0fa4-5449-4f17-b35f-6e0c11223301")!
        try database.execute(
            """
            INSERT INTO canonical_places (
                id,
                name_original,
                name_en,
                name_ru,
                name_he,
                address_original,
                address_en,
                address_ru,
                address_he,
                city,
                place_type,
                object_lat,
                object_lon,
                entrance_lat,
                entrance_lon,
                preferred_routing_lat,
                preferred_routing_lon,
                preferred_routing_point_type,
                search_tile_key,
                is_public,
                is_accessible,
                status,
                confidence_score,
                routing_quality,
                last_verified_at,
                created_at,
                updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """,
            bindings: [
                .text(placeID.uuidString.lowercased()),
                .text("מקלט ציבורי דיזנגוף"),
                .text("Dizengoff Public Shelter"),
                .text("Общественное укрытие Дизенгоф"),
                .text("מקלט ציבורי דיזנגוף"),
                .text("רחוב דיזנגוף 122"),
                .text("122 Dizengoff Street"),
                .text("улица Дизенгоф 122"),
                .text("רחוב דיזנגוף 122"),
                .text("Tel Aviv-Yafo"),
                .text(PlaceType.publicShelter.rawValue),
                .double(32.0853),
                .double(34.7818),
                .double(32.08542),
                .double(34.78163),
                .double(32.08542),
                .double(34.78163),
                .text(RoutingPointType.entrance.rawValue),
                .text(SearchTileKey.make(for: GeoCoordinate(latitude: 32.08542, longitude: 34.78163))),
                .bool(true),
                .bool(true),
                .text(PlaceStatus.active.rawValue),
                .double(0.96),
                .double(0.92),
                .text("2026-03-01T09:00:00.000Z"),
                .text("2026-01-15T10:00:00.000Z"),
                .text("2026-03-01T09:00:00.000Z")
            ]
        )

        let fetchedPlace = try SQLiteCanonicalPlaceRepository(database: database).fetch(id: placeID)

        XCTAssertEqual(fetchedPlace?.id, placeID)
        XCTAssertEqual(fetchedPlace?.name.bestValue(for: .english), "Dizengoff Public Shelter")
    }
}
