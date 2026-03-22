import XCTest
@testable import SheltersKit

final class DatabaseMigratorTests: XCTestCase {
    func testInitialMigrationCreatesFoundationTables() throws {
        let database = try SQLiteDatabase.inMemory()

        try DatabaseMigrator().migrate(database)

        let tableRows = try database.query(
            """
            SELECT name
            FROM sqlite_master
            WHERE type = 'table'
            ORDER BY name ASC;
            """
        )

        let names = Set(tableRows.compactMap { $0.string("name") })

        XCTAssertTrue(names.contains("canonical_places"))
        XCTAssertTrue(names.contains("routing_points"))
        XCTAssertTrue(names.contains("user_reports"))
        XCTAssertTrue(names.contains("photo_evidence"))
        XCTAssertTrue(names.contains("sync_metadata"))
        XCTAssertTrue(names.contains("app_settings"))
        XCTAssertTrue(names.contains("pending_uploads"))
        XCTAssertTrue(names.contains("place_history"))
        XCTAssertTrue(names.contains("source_attribution"))
    }

    func testInitialMigrationCreatesKeyIndexesForNearbyAndReporting() throws {
        let database = try SQLiteDatabase.inMemory()

        try DatabaseMigrator().migrate(database)

        let indexRows = try database.query(
            """
            SELECT name
            FROM sqlite_master
            WHERE type = 'index'
            ORDER BY name ASC;
            """
        )

        let indexNames = Set(indexRows.compactMap { $0.string("name") })

        XCTAssertTrue(indexNames.contains("idx_canonical_places_search_tile_key"))
        XCTAssertTrue(indexNames.contains("idx_canonical_places_preferred_routing_coords"))
        XCTAssertTrue(indexNames.contains("idx_routing_points_place_id"))
        XCTAssertTrue(indexNames.contains("idx_user_reports_place_id"))
        XCTAssertTrue(indexNames.contains("idx_photo_evidence_report_id"))
        XCTAssertTrue(indexNames.contains("idx_pending_uploads_state"))
    }
}
