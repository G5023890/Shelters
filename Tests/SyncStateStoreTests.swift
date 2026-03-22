import Foundation
import XCTest
@testable import SheltersKit

final class SyncStateStoreTests: XCTestCase {
    func testStoresAndLoadsSyncStatusSnapshot() throws {
        let database = try SQLiteDatabase.inMemory()
        try DatabaseMigrator().migrate(database)

        let repository = SQLiteSyncMetadataRepository(database: database)
        let store = RepositoryBackedSyncStateStore(repository: repository)
        let plan = AtomicDatabaseReplacementPlan(
            datasetVersion: "2026.03.12-01",
            liveDatabaseURL: URL(fileURLWithPath: "/tmp/live.sqlite"),
            stagedDatabaseURL: URL(fileURLWithPath: "/tmp/staged.sqlite"),
            backupDatabaseURL: URL(fileURLWithPath: "/tmp/backup.sqlite"),
            createdAt: Date()
        )
        let snapshot = SyncStatusSnapshot(
            installedDatasetVersion: "2026.03.01-01",
            remoteDatasetVersion: "2026.03.12-01",
            lastCheckedAt: Date(),
            lastSuccessfulSyncAt: nil,
            lastPreparedAt: Date(),
            lastErrorMessage: nil,
            activityState: .readyToReplaceDatabase,
            updateAvailability: .updateAvailable,
            preparedReplacementPlan: plan
        )

        try store.save(snapshot)
        let loaded = try store.load()

        XCTAssertEqual(loaded.installedDatasetVersion, snapshot.installedDatasetVersion)
        XCTAssertEqual(loaded.remoteDatasetVersion, snapshot.remoteDatasetVersion)
        XCTAssertEqual(loaded.activityState, .readyToReplaceDatabase)
        XCTAssertEqual(loaded.updateAvailability, .updateAvailable)
        XCTAssertEqual(loaded.preparedReplacementPlan?.datasetVersion, "2026.03.12-01")
        XCTAssertEqual(loaded.preparedReplacementPlan?.stagedDatabaseURL.path, "/tmp/staged.sqlite")
    }
}
