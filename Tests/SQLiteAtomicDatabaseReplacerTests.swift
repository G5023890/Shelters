import Foundation
import XCTest
@testable import SheltersKit

final class SQLiteAtomicDatabaseReplacerTests: XCTestCase {
    func testReplaceDatabaseRestoresBackupWhenStagedCandidateIsMissing() throws {
        let sandboxURL = try makeSandboxDirectory()
        let liveDatabaseURL = sandboxURL.appendingPathComponent("shelters.sqlite")
        let backupDatabaseURL = sandboxURL.appendingPathComponent("backup.sqlite")
        let missingStagedDatabaseURL = sandboxURL.appendingPathComponent("missing-staged.sqlite")

        do {
            let liveDatabase = try SQLiteDatabase(path: liveDatabaseURL.path)
            try DatabaseMigrator().migrate(liveDatabase)
            try SQLiteCanonicalPlaceRepository(database: liveDatabase).upsert([makePlace(name: "Live Shelter")])
            try liveDatabase.execute("PRAGMA wal_checkpoint(TRUNCATE);")
        }

        let replacer = SQLiteAtomicDatabaseReplacer()
        let plan = AtomicDatabaseReplacementPlan(
            datasetVersion: "2026.03.13-01",
            liveDatabaseURL: liveDatabaseURL,
            stagedDatabaseURL: missingStagedDatabaseURL,
            backupDatabaseURL: backupDatabaseURL,
            createdAt: Date()
        )

        do {
            try replacer.replaceDatabase(using: plan)
            XCTFail("Expected replacement to fail when staged database is missing.")
        } catch let error as AtomicDatabaseReplacementError {
            guard case .failedToReplaceDatabase = error else {
                return XCTFail("Unexpected replacement error: \(error)")
            }
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: liveDatabaseURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: backupDatabaseURL.path))

        let restoredDatabase = try SQLiteDatabase(path: liveDatabaseURL.path)
        XCTAssertEqual(try SQLiteCanonicalPlaceRepository(database: restoredDatabase).count(), 1)
    }

    private func makeSandboxDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SheltersAtomicSwapTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return directory
    }

    private func makePlace(name: String) -> CanonicalPlace {
        CanonicalPlace(
            id: UUID(),
            name: LocalizedPlaceText(original: nil, english: name, russian: nil, hebrew: nil),
            address: LocalizedPlaceText(original: nil, english: "1 Example Street", russian: nil, hebrew: nil),
            city: "Tel Aviv",
            placeType: .publicShelter,
            objectCoordinate: GeoCoordinate(latitude: 32.0853, longitude: 34.7818),
            entranceCoordinate: GeoCoordinate(latitude: 32.0854, longitude: 34.7819),
            preferredRoutingCoordinate: GeoCoordinate(latitude: 32.0854, longitude: 34.7819),
            preferredRoutingPointType: .entrance,
            isPublic: true,
            isAccessible: true,
            status: .active,
            confidenceScore: 0.9,
            routingQuality: 0.8,
            lastVerifiedAt: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
