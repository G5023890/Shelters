import Foundation
import XCTest
@testable import SheltersKit

final class SQLiteRoutingPointRepositoryTests: XCTestCase {
    func testFetchRoutingPointsMatchesPlaceIDCaseInsensitivelyForPublishedDatasets() throws {
        let database = try SQLiteDatabase.inMemory()
        try DatabaseMigrator().migrate(database)

        let placeID = UUID(uuidString: "0f4e0fa4-5449-4f17-b35f-6e0c11223302")!
        let routingPointID = UUID(uuidString: "8bdb40f3-5e40-4ef6-a0d5-4f7e11223302")!

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
                .text("חניון מוגן אבן גבירול"),
                .text("Ibn Gabirol Protected Parking"),
                .text("Защищённая парковка Ибн Гвироль"),
                .text("חניון מוגן אבן גבירול"),
                .text("רחוב אבן גבירול 64"),
                .text("64 Ibn Gabirol Street"),
                .text("улица Ибн Гвироль 64"),
                .text("רחוב אבן גבירול 64"),
                .text("Tel Aviv-Yafo"),
                .text(PlaceType.protectedParking.rawValue),
                .double(32.0806),
                .double(34.7801),
                .null,
                .null,
                .double(32.08045),
                .double(34.78029),
                .text(RoutingPointType.preferred.rawValue),
                .text(SearchTileKey.make(for: GeoCoordinate(latitude: 32.08045, longitude: 34.78029))),
                .bool(true),
                .bool(true),
                .text(PlaceStatus.active.rawValue),
                .double(0.79),
                .double(0.74),
                .text("2026-02-24T08:30:00.000Z"),
                .text("2026-01-15T10:00:00.000Z"),
                .text("2026-02-24T08:30:00.000Z")
            ]
        )

        try database.execute(
            """
            INSERT INTO routing_points (
                id,
                canonical_place_id,
                lat,
                lon,
                point_type,
                confidence,
                derived_from,
                created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?);
            """,
            bindings: [
                .text(routingPointID.uuidString.lowercased()),
                .text(placeID.uuidString.lowercased()),
                .double(32.08045),
                .double(34.78029),
                .text(RoutingPointType.preferred.rawValue),
                .double(0.74),
                .text("site_plan"),
                .text("2026-02-24T08:30:00.000Z")
            ]
        )

        let points = try SQLiteRoutingPointRepository(database: database).fetchRoutingPoints(for: placeID)

        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points.first?.id, routingPointID)
        XCTAssertEqual(points.first?.canonicalPlaceID, placeID)
        XCTAssertEqual(points.first?.pointType, .preferred)
    }
}
