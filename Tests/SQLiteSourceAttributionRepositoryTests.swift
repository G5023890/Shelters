import Foundation
import XCTest
@testable import SheltersKit

final class SQLiteSourceAttributionRepositoryTests: XCTestCase {
    func testFetchSourceAttributionsReturnsRowsForRequestedPlaceOnly() throws {
        let database = try SQLiteDatabase.inMemory()
        try DatabaseMigrator().migrate(database)

        let placeID = UUID(uuidString: "72FC0194-EA7F-48CC-802A-3F0D8D111001")!
        let otherPlaceID = UUID(uuidString: "72FC0194-EA7F-48CC-802A-3F0D8D111002")!

        try insertPlace(id: placeID, into: database)
        try insertPlace(id: otherPlaceID, into: database)

        try database.execute(
            """
            INSERT INTO source_attribution (id, canonical_place_id, source_name, source_identifier, imported_at)
            VALUES (?, ?, ?, ?, ?), (?, ?, ?, ?, ?);
            """,
            bindings: [
                .text("7cbe7ad3-1639-43ab-8bd5-aaa100000001"),
                .text(placeID.uuidString.lowercased()),
                .text("beer-sheva-municipal-shelters"),
                .text("source-1"),
                .text("2026-03-08T01:10:18.000Z"),
                .text("7cbe7ad3-1639-43ab-8bd5-aaa100000002"),
                .text(otherPlaceID.uuidString.lowercased()),
                .text("beer-sheva-municipal-shelters-itm"),
                .text("source-2"),
                .text("2026-03-08T01:10:24.000Z")
            ]
        )

        let fetched = try SQLiteSourceAttributionRepository(database: database).fetchSourceAttributions(for: placeID)

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.canonicalPlaceID, placeID)
        XCTAssertEqual(fetched.first?.sourceName, "beer-sheva-municipal-shelters")
    }

    private func insertPlace(id: UUID, into database: SQLiteDatabase) throws {
        try database.execute(
            """
            INSERT INTO canonical_places (
                id, name_original, name_en, name_ru, name_he,
                address_original, address_en, address_ru, address_he,
                city, place_type, object_lat, object_lon, entrance_lat, entrance_lon,
                preferred_routing_lat, preferred_routing_lon, preferred_routing_point_type, search_tile_key,
                is_public, is_accessible, status, confidence_score, routing_quality, last_verified_at, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """,
            bindings: [
                .text(id.uuidString.lowercased()),
                .text("Sample"),
                .text("Sample"),
                .null,
                .null,
                .null,
                .null,
                .null,
                .null,
                .text("Beer Sheva"),
                .text(PlaceType.publicShelter.rawValue),
                .double(31.2589),
                .double(34.8081),
                .null,
                .null,
                .double(31.2589),
                .double(34.8081),
                .text(RoutingPointType.object.rawValue),
                .text(SearchTileKey.make(for: GeoCoordinate(latitude: 31.2589, longitude: 34.8081))),
                .bool(true),
                .bool(false),
                .text(PlaceStatus.active.rawValue),
                .double(0.8),
                .double(0.7),
                .text("2026-03-08T01:10:18.000Z"),
                .text("2026-03-08T01:10:18.000Z"),
                .text("2026-03-08T01:10:18.000Z")
            ]
        )
    }
}
