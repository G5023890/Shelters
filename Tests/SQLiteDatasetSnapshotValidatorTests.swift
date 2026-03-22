import Foundation
import XCTest
@testable import SheltersKit

final class SQLiteDatasetSnapshotValidatorTests: XCTestCase {
    func testValidatorAcceptsSnapshotWithExpectedSchemaAndTables() throws {
        let databaseURL = try makeDatabaseURL(name: "validator-valid")
        let database = try SQLiteDatabase(path: databaseURL.path)
        try DatabaseMigrator().migrate(database)

        let validator = SQLiteDatasetSnapshotValidator()
        let metadata = DatasetVersionInfo(
            datasetVersion: "2026.03.13-01",
            publishedAt: Date(),
            buildNumber: 13,
            checksum: "abc",
            downloadURL: URL(string: "https://example.com/shelters.sqlite")!,
            schemaVersion: DatabaseSchemaMigrations.latestVersion,
            minimumClientVersion: nil,
            fileSize: nil,
            recordCount: 0
        )

        XCTAssertNoThrow(
            try validator.validateSnapshot(
                at: databaseURL,
                metadata: metadata,
                supportedSchemaVersion: DatabaseSchemaMigrations.latestVersion,
                currentClientVersion: "1.0.0"
            )
        )
    }

    func testValidatorRejectsSnapshotMissingRequiredTables() throws {
        let databaseURL = try makeDatabaseURL(name: "validator-invalid")
        let database = try SQLiteDatabase(path: databaseURL.path)
        try database.execute("CREATE TABLE only_one_table (id TEXT PRIMARY KEY NOT NULL);")

        let validator = SQLiteDatasetSnapshotValidator()
        let metadata = DatasetVersionInfo(
            datasetVersion: "2026.03.13-01",
            publishedAt: Date(),
            buildNumber: 13,
            checksum: "abc",
            downloadURL: URL(string: "https://example.com/shelters.sqlite")!,
            schemaVersion: DatabaseSchemaMigrations.latestVersion,
            minimumClientVersion: nil,
            fileSize: nil,
            recordCount: 0
        )

        XCTAssertThrowsError(
            try validator.validateSnapshot(
                at: databaseURL,
                metadata: metadata,
                supportedSchemaVersion: DatabaseSchemaMigrations.latestVersion,
                currentClientVersion: "1.0.0"
            )
        ) { error in
            guard case SyncExecutionError.downloadedSnapshotMissingRequiredTables = error else {
                return XCTFail("Expected missing required tables error, got \(error)")
            }
        }
    }

    private func makeDatabaseURL(name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SheltersTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return directory.appendingPathComponent("\(name).sqlite")
    }
}
