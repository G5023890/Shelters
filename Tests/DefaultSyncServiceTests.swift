import CryptoKit
import Foundation
import XCTest
@testable import SheltersKit

final class DefaultSyncServiceTests: XCTestCase {
    func testSynchronizeNowInstallsDownloadedSnapshotAndPreservesLocalReports() async throws {
        let sandboxURL = try makeSandboxDirectory()
        let liveDatabaseURL = sandboxURL.appendingPathComponent("shelters.sqlite")
        let remoteWorkingDatabaseURL = sandboxURL.appendingPathComponent("remote-working.sqlite")
        let remoteSnapshotURL = sandboxURL.appendingPathComponent("remote-snapshot.sqlite")

        let liveDatabase = try SQLiteDatabase(path: liveDatabaseURL.path)
        try DatabaseMigrator().migrate(liveDatabase)

        let livePlaceRepository = SQLiteCanonicalPlaceRepository(database: liveDatabase)
        let liveReportRepository = SQLiteUserReportRepository(database: liveDatabase)
        let liveSyncMetadataRepository = SQLiteSyncMetadataRepository(database: liveDatabase)
        let stateStore = RepositoryBackedSyncStateStore(repository: liveSyncMetadataRepository)

        try livePlaceRepository.upsert([makePlace(name: "Live Shelter")])
        try liveReportRepository.save(
            UserReport(
                id: UUID(),
                canonicalPlaceID: nil,
                reportType: .wrongLocation,
                reportStatus: .pendingUpload,
                userCoordinate: GeoCoordinate(latitude: 32.0853, longitude: 34.7818),
                suggestedEntranceCoordinate: nil,
                textNote: "Keep me",
                datasetVersion: "2026.03.01-01",
                localCreatedAt: Date(),
                uploadedAt: nil
            )
        )
        try stateStore.save(
            SyncStatusSnapshot.initial.updating(
                installedDatasetVersion: .replace("2026.03.01-01"),
                activityState: .upToDate,
                updateAvailability: .upToDate
            )
        )

        do {
            let remoteDatabase = try SQLiteDatabase(path: remoteWorkingDatabaseURL.path)
            try DatabaseMigrator().migrate(remoteDatabase)
            try SQLiteCanonicalPlaceRepository(database: remoteDatabase).upsert([
                makePlace(name: "Remote Shelter A"),
                makePlace(name: "Remote Shelter B")
            ])
            try remoteDatabase.execute("PRAGMA wal_checkpoint(TRUNCATE);")
            try remoteDatabase.execute("VACUUM INTO ?;", bindings: [.text(remoteSnapshotURL.path)])
        }

        let checksum = try sha256(for: remoteSnapshotURL)
        let metadata = DatasetVersionResponseDTO(
            datasetVersion: "2026.03.13-01",
            publishedAt: Date(),
            buildNumber: 99,
            checksum: checksum,
            downloadURL: URL(string: "https://example.com/shelters.sqlite")!,
            schemaVersion: DatabaseSchemaMigrations.latestVersion,
            minimumClientVersion: nil,
            fileSize: nil,
            recordCount: 2
        )

        let service = DefaultSyncService(
            stateStore: stateStore,
            remoteMetadataSource: StubRemoteDatasetMetadataSource(dto: metadata),
            datasetFileDownloader: StubDatasetFileDownloader(fileURL: remoteSnapshotURL),
            checksumValidator: SHA256DatasetChecksumValidator(),
            snapshotValidator: SQLiteDatasetSnapshotValidator(),
            localStatePreserver: SQLiteLocalDatabaseStatePreserver(),
            databaseReplacer: SQLiteAtomicDatabaseReplacer(),
            clientVersionProvider: StubClientVersionProvider(version: "1.0.0"),
            liveDatabase: liveDatabase,
            liveDatabaseURL: liveDatabaseURL,
            fileManager: .default
        )

        let result = await service.synchronizeNow()

        XCTAssertTrue(result.didInstallUpdate)
        XCTAssertEqual(result.snapshot.installedDatasetVersion, "2026.03.13-01")
        XCTAssertEqual(result.snapshot.activityState, .upToDate)
        XCTAssertEqual(result.snapshot.updateAvailability, .upToDate)
        XCTAssertEqual(try SQLiteCanonicalPlaceRepository(database: liveDatabase).count(), 2)
        XCTAssertEqual(try liveReportRepository.fetchPendingReports().count, 1)
        let persistedSyncStatus = await service.fetchSyncStatus()
        XCTAssertEqual(persistedSyncStatus.installedDatasetVersion, "2026.03.13-01")
    }

    func testSynchronizeNowRollsBackToExistingLiveDatabaseWhenReplacementFails() async throws {
        let sandboxURL = try makeSandboxDirectory()
        let liveDatabaseURL = sandboxURL.appendingPathComponent("shelters.sqlite")
        let remoteWorkingDatabaseURL = sandboxURL.appendingPathComponent("remote-working.sqlite")
        let remoteSnapshotURL = sandboxURL.appendingPathComponent("remote-snapshot.sqlite")

        let liveDatabase = try SQLiteDatabase(path: liveDatabaseURL.path)
        try DatabaseMigrator().migrate(liveDatabase)

        let livePlaceRepository = SQLiteCanonicalPlaceRepository(database: liveDatabase)
        let liveReportRepository = SQLiteUserReportRepository(database: liveDatabase)
        let liveSyncMetadataRepository = SQLiteSyncMetadataRepository(database: liveDatabase)
        let settingsService = DefaultAppSettingsService(
            repository: SQLiteAppSettingsRepository(database: liveDatabase)
        )
        let stateStore = RepositoryBackedSyncStateStore(repository: liveSyncMetadataRepository)

        try livePlaceRepository.upsert([makePlace(name: "Live Shelter")])
        try liveReportRepository.save(
            UserReport(
                id: UUID(),
                canonicalPlaceID: nil,
                reportType: .wrongLocation,
                reportStatus: .pendingUpload,
                userCoordinate: GeoCoordinate(latitude: 32.0853, longitude: 34.7818),
                suggestedEntranceCoordinate: nil,
                textNote: "Keep me safe",
                datasetVersion: "2026.03.01-01",
                localCreatedAt: Date(),
                uploadedAt: nil
            )
        )
        try await settingsService.setPreferredRoutingProvider(.googleMaps)
        try stateStore.save(
            SyncStatusSnapshot.initial.updating(
                installedDatasetVersion: .replace("2026.03.01-01"),
                activityState: .upToDate,
                updateAvailability: .upToDate
            )
        )

        do {
            let remoteDatabase = try SQLiteDatabase(path: remoteWorkingDatabaseURL.path)
            try DatabaseMigrator().migrate(remoteDatabase)
            try SQLiteCanonicalPlaceRepository(database: remoteDatabase).upsert([
                makePlace(name: "Remote Shelter A"),
                makePlace(name: "Remote Shelter B")
            ])
            try remoteDatabase.execute("PRAGMA wal_checkpoint(TRUNCATE);")
            try remoteDatabase.execute("VACUUM INTO ?;", bindings: [.text(remoteSnapshotURL.path)])
        }

        let checksum = try sha256(for: remoteSnapshotURL)
        let metadata = DatasetVersionResponseDTO(
            datasetVersion: "2026.03.13-01",
            publishedAt: Date(),
            buildNumber: 100,
            checksum: checksum,
            downloadURL: URL(string: "https://example.com/shelters.sqlite")!,
            schemaVersion: DatabaseSchemaMigrations.latestVersion,
            minimumClientVersion: nil,
            fileSize: nil,
            recordCount: 2
        )

        let service = DefaultSyncService(
            stateStore: stateStore,
            remoteMetadataSource: StubRemoteDatasetMetadataSource(dto: metadata),
            datasetFileDownloader: StubDatasetFileDownloader(fileURL: remoteSnapshotURL),
            checksumValidator: SHA256DatasetChecksumValidator(),
            snapshotValidator: SQLiteDatasetSnapshotValidator(),
            localStatePreserver: SQLiteLocalDatabaseStatePreserver(),
            databaseReplacer: RestoringFailingAtomicDatabaseReplacer(),
            clientVersionProvider: StubClientVersionProvider(version: "1.0.0"),
            liveDatabase: liveDatabase,
            liveDatabaseURL: liveDatabaseURL,
            fileManager: .default
        )

        let result = await service.synchronizeNow()

        XCTAssertFalse(result.didInstallUpdate)
        XCTAssertEqual(result.snapshot.installedDatasetVersion, "2026.03.01-01")
        XCTAssertEqual(result.snapshot.remoteDatasetVersion, "2026.03.13-01")
        XCTAssertEqual(result.snapshot.activityState, .failed)
        XCTAssertEqual(result.snapshot.updateAvailability, .updateAvailable)
        XCTAssertNotNil(result.snapshot.lastErrorMessage)
        XCTAssertEqual(try livePlaceRepository.count(), 1)
        XCTAssertEqual(try liveReportRepository.fetchPendingReports().count, 1)

        let restoredSettings = try await settingsService.loadSettings()
        XCTAssertEqual(restoredSettings.preferredRoutingProvider, .googleMaps)

        let persistedSyncStatus = await service.fetchSyncStatus()
        XCTAssertEqual(persistedSyncStatus.installedDatasetVersion, "2026.03.01-01")
        XCTAssertEqual(persistedSyncStatus.activityState, .failed)
        XCTAssertEqual(persistedSyncStatus.updateAvailability, .updateAvailable)
        XCTAssertNotNil(persistedSyncStatus.lastErrorMessage)
    }

    private func makeSandboxDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SheltersSyncTests-\(UUID().uuidString)", isDirectory: true)
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

    private func sha256(for fileURL: URL) throws -> String {
        let data = try Data(contentsOf: fileURL)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

private struct StubRemoteDatasetMetadataSource: RemoteDatasetMetadataFetching {
    let dto: DatasetVersionResponseDTO

    func fetchLatestVersionResponse() async throws -> DatasetVersionResponseDTO {
        dto
    }
}

private struct StubDatasetFileDownloader: DatasetFileDownloading {
    let fileURL: URL

    func download(from remoteURL: URL) async throws -> DownloadedDatasetFile {
        let downloadURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SheltersDownloaded-\(UUID().uuidString).sqlite")
        try FileManager.default.copyItem(at: fileURL, to: downloadURL)

        return DownloadedDatasetFile(
            fileURL: downloadURL,
            suggestedFilename: fileURL.lastPathComponent,
            expectedContentLength: nil
        )
    }
}

private struct StubClientVersionProvider: ClientVersionProviding {
    let version: String

    func currentVersion() -> String {
        version
    }
}

private struct RestoringFailingAtomicDatabaseReplacer: AtomicDatabaseReplacing {
    private let wrapped = SQLiteAtomicDatabaseReplacer()

    func stageReplacementCandidate(
        downloadedFileURL: URL,
        liveDatabaseURL: URL,
        datasetVersion: String
    ) throws -> AtomicDatabaseReplacementPlan {
        try wrapped.stageReplacementCandidate(
            downloadedFileURL: downloadedFileURL,
            liveDatabaseURL: liveDatabaseURL,
            datasetVersion: datasetVersion
        )
    }

    func replaceDatabase(using plan: AtomicDatabaseReplacementPlan) throws {
        let fileManager = FileManager.default

        let walURL = plan.liveDatabaseURL.appendingPathExtension("wal")
        let shmURL = plan.liveDatabaseURL.appendingPathExtension("shm")

        if fileManager.fileExists(atPath: walURL.path) {
            try fileManager.removeItem(at: walURL)
        }

        if fileManager.fileExists(atPath: shmURL.path) {
            try fileManager.removeItem(at: shmURL)
        }

        if fileManager.fileExists(atPath: plan.backupDatabaseURL.path) {
            try fileManager.removeItem(at: plan.backupDatabaseURL)
        }

        try fileManager.moveItem(at: plan.liveDatabaseURL, to: plan.backupDatabaseURL)
        try fileManager.moveItem(at: plan.backupDatabaseURL, to: plan.liveDatabaseURL)

        if fileManager.fileExists(atPath: plan.stagedDatabaseURL.path) {
            try? fileManager.removeItem(at: plan.stagedDatabaseURL)
        }

        throw AtomicDatabaseReplacementError.failedToReplaceDatabase
    }
}
