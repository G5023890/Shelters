import CryptoKit
import Foundation
import XCTest
@testable import SheltersKit

#if canImport(Darwin)
import Darwin
#endif

final class LocalDatasetWorkflowValidationTests: XCTestCase {
    func testBuilderProducesCompatibleArtifactsWithExpectedCoverage() throws {
        let artifacts = try generateDataset(downloadBaseURL: URL(string: "http://127.0.0.1:8999")!)

        XCTAssertTrue(FileManager.default.fileExists(atPath: artifacts.snapshotURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: artifacts.metadataURL.path))
        XCTAssertEqual(try sha256(for: artifacts.snapshotURL), artifacts.metadata.checksum)
        XCTAssertEqual(artifacts.metadata.schemaVersion, DatabaseSchemaMigrations.latestVersion)
        XCTAssertEqual(artifacts.metadata.recordCount, 24)

        let database = try SQLiteDatabase(path: artifacts.snapshotURL.path)
        let tableNames = try requiredTableNames(in: database)
        XCTAssertTrue(expectedRequiredTables.isSubset(of: tableNames))
        XCTAssertTrue(optionalFoundationTables.isSubset(of: tableNames))
        XCTAssertEqual(try schemaVersion(in: database), DatabaseSchemaMigrations.latestVersion)

        XCTAssertGreaterThan(
            try count(in: database, sql: "SELECT COUNT(*) AS value FROM canonical_places WHERE entrance_lat IS NOT NULL;"),
            0
        )
        XCTAssertGreaterThan(
            try count(in: database, sql: "SELECT COUNT(*) AS value FROM canonical_places WHERE entrance_lat IS NULL;"),
            0
        )
        XCTAssertGreaterThanOrEqual(
            try count(in: database, sql: "SELECT COUNT(DISTINCT place_type) AS value FROM canonical_places;"),
            4
        )

        let confidenceRows = try database.query(
            "SELECT MIN(confidence_score) AS min_confidence, MAX(confidence_score) AS max_confidence FROM canonical_places;"
        )
        let confidenceRow = try XCTUnwrap(confidenceRows.first)
        XCTAssertLessThan(try XCTUnwrap(confidenceRow.double("min_confidence")), 0.6)
        XCTAssertGreaterThan(try XCTUnwrap(confidenceRow.double("max_confidence")), 0.9)

        let multilingualPlace = try XCTUnwrap(
            try SQLiteCanonicalPlaceRepository(database: database).fetch(
                id: UUID(uuidString: "0f4e0fa4-5449-4f17-b35f-6e0c11223301")!
            )
        )
        XCTAssertEqual(multilingualPlace.name.bestValue(for: .english), "Dizengoff Public Shelter")
        XCTAssertEqual(multilingualPlace.name.bestValue(for: .russian), "Общественное укрытие Дизенгоф")
        XCTAssertEqual(multilingualPlace.name.bestValue(for: .hebrew), "מקלט ציבורי דיזנגוף")
    }

    func testGeneratedDatasetCanBeServedLocallyAndConsumedByDefaultSyncService() async throws {
        let port = try makeAvailablePort()
        let artifacts = try generateDataset(downloadBaseURL: URL(string: "http://127.0.0.1:\(port)")!)
        let server = try startLocalHTTPServer(serving: artifacts.outputDirectoryURL, port: port)
        defer { terminate(process: server) }

        let remoteMetadataURL = URL(string: "http://127.0.0.1:\(port)/dataset-metadata.json")!
        try await waitForServer(at: remoteMetadataURL)

        let sandboxURL = try makeSandboxDirectory()
        let liveDatabaseURL = sandboxURL.appendingPathComponent("live.sqlite")
        let liveDatabase = try SQLiteDatabase(path: liveDatabaseURL.path)
        try DatabaseMigrator().migrate(liveDatabase)

        let livePlaceRepository = SQLiteCanonicalPlaceRepository(database: liveDatabase)
        let liveReportRepository = SQLiteUserReportRepository(database: liveDatabase)
        let liveSyncMetadataRepository = SQLiteSyncMetadataRepository(database: liveDatabase)
        let stateStore = RepositoryBackedSyncStateStore(repository: liveSyncMetadataRepository)

        try livePlaceRepository.upsert([makeSeedPlace(name: "Older Local Shelter")])
        try liveReportRepository.save(
            UserReport(
                id: UUID(),
                canonicalPlaceID: nil,
                reportType: .wrongLocation,
                reportStatus: .pendingUpload,
                userCoordinate: GeoCoordinate(latitude: 32.0853, longitude: 34.7818),
                suggestedEntranceCoordinate: nil,
                textNote: "Preserve me on sync",
                datasetVersion: "2026.03.01-legacy",
                localCreatedAt: Date(),
                uploadedAt: nil
            )
        )
        try stateStore.save(
            SyncStatusSnapshot.initial.updating(
                installedDatasetVersion: .replace("2026.03.01-legacy"),
                activityState: .upToDate,
                updateAvailability: .upToDate
            )
        )

        let service = DefaultSyncService(
            stateStore: stateStore,
            remoteMetadataSource: URLSessionRemoteDatasetMetadataSource(
                endpoint: remoteMetadataURL,
                session: .shared
            ),
            datasetFileDownloader: URLSessionTemporaryFileDownloader(session: .shared),
            checksumValidator: SHA256DatasetChecksumValidator(),
            snapshotValidator: SQLiteDatasetSnapshotValidator(),
            localStatePreserver: SQLiteLocalDatabaseStatePreserver(),
            databaseReplacer: SQLiteAtomicDatabaseReplacer(),
            clientVersionProvider: LocalDatasetStubClientVersionProvider(version: "1.0.0"),
            liveDatabase: liveDatabase,
            liveDatabaseURL: liveDatabaseURL,
            fileManager: .default
        )

        let result = await service.synchronizeNow()

        XCTAssertTrue(result.didInstallUpdate)
        XCTAssertEqual(result.snapshot.installedDatasetVersion, artifacts.metadata.datasetVersion)
        XCTAssertEqual(result.snapshot.activityState, .upToDate)
        XCTAssertEqual(result.snapshot.updateAvailability, .upToDate)
        XCTAssertEqual(try livePlaceRepository.count(), artifacts.metadata.recordCount)
        XCTAssertEqual(try liveReportRepository.fetchPendingReports().count, 1)

        let persistedStatus = await service.fetchSyncStatus()
        XCTAssertEqual(persistedStatus.installedDatasetVersion, artifacts.metadata.datasetVersion)
        XCTAssertEqual(persistedStatus.activityState, .upToDate)
        XCTAssertEqual(persistedStatus.updateAvailability, .upToDate)
    }

    func testGeneratedDatasetSupportsNearbySearchSanityForTelAvivCluster() async throws {
        let artifacts = try generateDataset(downloadBaseURL: URL(string: "http://127.0.0.1:8998")!)
        let database = try SQLiteDatabase(path: artifacts.snapshotURL.path)
        let service = LocalNearbySearchService(
            placeRepository: SQLiteCanonicalPlaceRepository(database: database),
            routingPointRepository: SQLiteRoutingPointRepository(database: database)
        )

        let telAvivCenter = GeoCoordinate(latitude: 32.0853, longitude: 34.7818)
        let results = try await service.searchNearby(from: telAvivCenter, radiusMeters: 2_000, limit: 5)

        XCTAssertGreaterThanOrEqual(results.count, 2)
        XCTAssertEqual(results.first?.place.name.bestValue(for: .english), "Dizengoff Public Shelter")
        XCTAssertTrue(results.prefix(2).allSatisfy { $0.place.city == "Tel Aviv-Yafo" })
        XCTAssertTrue(results.prefix(2).contains { $0.routingTarget.source == .placeEntrance })
    }

    private var expectedRequiredTables: Set<String> {
        [
            "app_settings",
            "canonical_places",
            "pending_uploads",
            "photo_evidence",
            "routing_points",
            "schema_migrations",
            "sync_metadata",
            "user_reports"
        ]
    }

    private var optionalFoundationTables: Set<String> {
        [
            "place_history",
            "source_attribution"
        ]
    }

    private func generateDataset(downloadBaseURL: URL) throws -> GeneratedDatasetArtifacts {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let outputDirectoryURL = try makeSandboxDirectory()

        let process = Process()
        let outputPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.currentDirectoryURL = repoRoot
        process.arguments = [
            repoRoot.appendingPathComponent("Tools/DatasetBuilder/build_sample_dataset.sh").path,
            "--output-dir", outputDirectoryURL.path,
            "--download-base-url", downloadBaseURL.absoluteString
        ]
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            XCTFail(output)
            throw ValidationTestError.builderFailed
        }

        let snapshotURL = outputDirectoryURL.appendingPathComponent("shelters.sqlite")
        let metadataURL = outputDirectoryURL.appendingPathComponent("dataset-metadata.json")
        let metadataData = try Data(contentsOf: metadataURL)
        let metadata = try SyncCoding.decoder().decode(DatasetVersionResponseDTO.self, from: metadataData)

        return GeneratedDatasetArtifacts(
            outputDirectoryURL: outputDirectoryURL,
            snapshotURL: snapshotURL,
            metadataURL: metadataURL,
            metadata: metadata
        )
    }

    private func requiredTableNames(in database: SQLiteDatabase) throws -> Set<String> {
        let rows = try database.query(
            """
            SELECT name
            FROM sqlite_master
            WHERE type = 'table'
            ORDER BY name ASC;
            """
        )
        return Set(rows.compactMap { $0.string("name") })
    }

    private func schemaVersion(in database: SQLiteDatabase) throws -> Int {
        let rows = try database.query("SELECT MAX(version) AS version FROM schema_migrations;")
        return Int(try XCTUnwrap(rows.first?.int64("version")))
    }

    private func count(in database: SQLiteDatabase, sql: String) throws -> Int {
        let rows = try database.query(sql)
        return Int(try XCTUnwrap(rows.first?.int64("value")))
    }

    private func sha256(for fileURL: URL) throws -> String {
        let data = try Data(contentsOf: fileURL)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func makeSandboxDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SheltersValidation-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return directory
    }

    private func startLocalHTTPServer(serving directoryURL: URL, port: UInt16) throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.currentDirectoryURL = directoryURL
        process.arguments = ["-m", "http.server", String(port), "--bind", "127.0.0.1"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        return process
    }

    private func terminate(process: Process) {
        guard process.isRunning else { return }
        process.terminate()
        process.waitUntilExit()
    }

    private func waitForServer(at url: URL) async throws {
        let session = URLSession(configuration: .ephemeral)
        for _ in 0..<20 {
            do {
                let (_, response) = try await session.data(from: url)
                if let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) {
                    return
                }
            } catch {
                try await Task.sleep(nanoseconds: 150_000_000)
                continue
            }
            try await Task.sleep(nanoseconds: 150_000_000)
        }

        XCTFail("Local metadata server did not become ready at \(url.absoluteString)")
    }

    private func makeSeedPlace(name: String) -> CanonicalPlace {
        CanonicalPlace(
            id: UUID(),
            name: LocalizedPlaceText(original: nil, english: name, russian: nil, hebrew: nil),
            address: LocalizedPlaceText(original: nil, english: "1 Local Street", russian: nil, hebrew: nil),
            city: "Tel Aviv-Yafo",
            placeType: .publicShelter,
            objectCoordinate: GeoCoordinate(latitude: 32.085, longitude: 34.782),
            entranceCoordinate: GeoCoordinate(latitude: 32.0851, longitude: 34.7819),
            preferredRoutingCoordinate: GeoCoordinate(latitude: 32.0851, longitude: 34.7819),
            preferredRoutingPointType: .entrance,
            isPublic: true,
            isAccessible: true,
            status: .active,
            confidenceScore: 0.8,
            routingQuality: 0.75,
            lastVerifiedAt: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    private func makeAvailablePort() throws -> UInt16 {
        #if canImport(Darwin)
        let socketDescriptor = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard socketDescriptor >= 0 else {
            throw ValidationTestError.unableToAllocatePort
        }
        defer { Darwin.close(socketDescriptor) }

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(0).bigEndian
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        let bindResult = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(socketDescriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            throw ValidationTestError.unableToAllocatePort
        }

        var boundAddress = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &boundAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.getsockname(socketDescriptor, $0, &length)
            }
        }
        guard nameResult == 0 else {
            throw ValidationTestError.unableToAllocatePort
        }

        return UInt16(bigEndian: boundAddress.sin_port)
        #else
        throw ValidationTestError.unableToAllocatePort
        #endif
    }
}

private struct GeneratedDatasetArtifacts {
    let outputDirectoryURL: URL
    let snapshotURL: URL
    let metadataURL: URL
    let metadata: DatasetVersionResponseDTO
}

private struct LocalDatasetStubClientVersionProvider: ClientVersionProviding {
    let version: String

    func currentVersion() -> String {
        version
    }
}

private enum ValidationTestError: LocalizedError {
    case unableToAllocatePort
    case builderFailed

    var errorDescription: String? {
        switch self {
        case .unableToAllocatePort:
            return "Could not allocate a local TCP port for validation."
        case .builderFailed:
            return "Dataset builder failed during local validation."
        }
    }
}
