import CryptoKit
import Foundation
import XCTest
@testable import SheltersKit

final class ExternalSourceDatasetBuilderTests: XCTestCase {
    func testBeerShevaSourceSnapshotBuildProducesCompatibleSQLiteOutput() throws {
        let artifacts = try buildBeerShevaDatasetFromSnapshot()

        XCTAssertTrue(FileManager.default.fileExists(atPath: artifacts.snapshotURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: artifacts.metadataURL.path))
        XCTAssertEqual(try sha256(for: artifacts.snapshotURL), artifacts.metadata.checksum)
        XCTAssertEqual(artifacts.metadata.schemaVersion, DatabaseSchemaMigrations.latestVersion)
        XCTAssertEqual(artifacts.metadata.recordCount, 262)
        XCTAssertTrue(artifacts.metadata.datasetVersion.hasPrefix("beer-sheva-shelters-"))

        let database = try SQLiteDatabase(path: artifacts.snapshotURL.path)
        XCTAssertEqual(try count(in: database, sql: "SELECT COUNT(*) AS value FROM canonical_places;"), 262)
        XCTAssertEqual(
            try count(in: database, sql: "SELECT COUNT(*) AS value FROM source_attribution;"),
            262
        )
        XCTAssertEqual(
            try count(
                in: database,
                sql: "SELECT COUNT(*) AS value FROM canonical_places WHERE place_type = 'public_shelter';"
            ),
            262
        )
        XCTAssertEqual(
            try count(
                in: database,
                sql: "SELECT COUNT(*) AS value FROM canonical_places WHERE entrance_lat IS NULL AND entrance_lon IS NULL;"
            ),
            262
        )
        XCTAssertEqual(
            try count(
                in: database,
                sql: "SELECT COUNT(*) AS value FROM canonical_places WHERE city = 'Beer Sheva';"
            ),
            262
        )
        XCTAssertEqual(
            try count(
                in: database,
                sql: """
                SELECT COUNT(*) AS value
                FROM canonical_places
                WHERE name_en IS NOT NULL
                  AND name_ru IS NOT NULL
                  AND name_he IS NOT NULL;
                """
            ),
            262
        )
        XCTAssertEqual(
            try count(
                in: database,
                sql: """
                SELECT COUNT(*) AS value
                FROM canonical_places
                WHERE name_en = 'Beer Sheva Shelter ג/2';
                """
            ),
            1
        )
    }

    func testBeerShevaITMSourceSnapshotBuildProducesCompatibleSQLiteOutput() throws {
        let repoRoot = repositoryRoot()
        let outputDirectoryURL = try makeSandboxDirectory()
        let artifacts = try buildDataset(
            scriptURL: repoRoot.appendingPathComponent("Tools/DatasetBuilder/build_sample_dataset.sh"),
            arguments: [
                "--source", "beer-sheva-shelters-itm",
                "--source-snapshot", repoRoot.appendingPathComponent(
                    "Tools/DatasetBuilder/Input/Raw/beer-sheva-shelters-itm-datastore.json"
                ).path,
                "--output-dir", outputDirectoryURL.path
            ]
        )

        XCTAssertEqual(artifacts.metadata.recordCount, 262)
        XCTAssertTrue(artifacts.metadata.datasetVersion.hasPrefix("beer-sheva-shelters-itm-"))

        let database = try SQLiteDatabase(path: artifacts.snapshotURL.path)
        XCTAssertEqual(try count(in: database, sql: "SELECT COUNT(*) AS value FROM canonical_places;"), 262)
        XCTAssertEqual(
            try count(
                in: database,
                sql: "SELECT COUNT(*) AS value FROM source_attribution WHERE source_name = 'beer-sheva-municipal-shelters-itm';"
            ),
            262
        )

        let wgsSourceURL = repoRoot.appendingPathComponent("Tools/DatasetBuilder/Input/Raw/beer-sheva-shelters-datastore.json")
        let rawSnapshot = try JSONDecoder().decode(TestBeerShevaSheltersRawSnapshot.self, from: Data(contentsOf: wgsSourceURL))
        let referenceByName = Dictionary(uniqueKeysWithValues: rawSnapshot.records.map { ($0.name, ($0.latitude, $0.longitude)) })
        let sampleRows = try database.query(
            """
                SELECT name_original, object_lat, object_lon
                FROM canonical_places
                WHERE name_original IN ('ג/2', 'ג/40')
                ORDER BY name_original;
                """
            )

        XCTAssertEqual(sampleRows.count, 2)
        for row in sampleRows {
            let name = try XCTUnwrap(row.string("name_original"))
            let reference = try XCTUnwrap(referenceByName[name])
            let actualLat = try XCTUnwrap(row.double("object_lat"))
            let actualLon = try XCTUnwrap(row.double("object_lon"))
            XCTAssertLessThan(
                testHaversineDistanceMeters(
                    latitudeA: reference.0,
                    longitudeA: reference.1,
                    latitudeB: actualLat,
                    longitudeB: actualLon
                ),
                1.0
            )
        }
    }

    func testBeerShevaCanonicalDatasetBuildMergesTwoSourcesIntoOneCanonicalDataset() throws {
        let repoRoot = repositoryRoot()
        let outputDirectoryURL = try makeSandboxDirectory()
        let artifacts = try buildDataset(
            scriptURL: repoRoot.appendingPathComponent("Tools/DatasetBuilder/build_beer_sheva_canonical_dataset.sh"),
            arguments: ["--output-dir", outputDirectoryURL.path]
        )

        let reviewURL = outputDirectoryURL.appendingPathComponent("dedupe-review.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: reviewURL.path))
        XCTAssertEqual(artifacts.metadata.recordCount, 262)
        XCTAssertTrue(artifacts.metadata.datasetVersion.hasPrefix("beer-sheva-canonical-v1-"))

        let reviewData = try Data(contentsOf: reviewURL)
        let reviewReport = try JSONDecoder().decode(TestDedupeReviewReport.self, from: reviewData)
        XCTAssertEqual(reviewReport.mergedCanonicalCount, 262)
        XCTAssertEqual(reviewReport.reviewCaseCount, 0)

        let database = try SQLiteDatabase(path: artifacts.snapshotURL.path)
        XCTAssertEqual(try count(in: database, sql: "SELECT COUNT(*) AS value FROM canonical_places;"), 262)
        XCTAssertEqual(try count(in: database, sql: "SELECT COUNT(*) AS value FROM source_attribution;"), 524)
        XCTAssertEqual(
            try count(
                in: database,
                sql: """
                SELECT COUNT(*) AS value
                FROM source_attribution
                GROUP BY canonical_place_id
                HAVING COUNT(*) = 2;
                """
            ),
            262
        )

        let sampleRow = try XCTUnwrap(
            database.query(
                """
                SELECT confidence_score, routing_quality
                FROM canonical_places
                WHERE name_original = 'ג/2'
                LIMIT 1;
                """
            ).first
        )
        XCTAssertGreaterThan(try XCTUnwrap(sampleRow.double("confidence_score")), 0.90)
        XCTAssertGreaterThan(try XCTUnwrap(sampleRow.double("routing_quality")), 0.60)
    }

    private func buildBeerShevaDatasetFromSnapshot() throws -> BuiltDatasetArtifacts {
        let repoRoot = repositoryRoot()
        let outputDirectoryURL = try makeSandboxDirectory()

        return try buildDataset(
            scriptURL: repoRoot.appendingPathComponent("Tools/DatasetBuilder/build_beer_sheva_dataset.sh"),
            arguments: ["--output-dir", outputDirectoryURL.path]
        )
    }

    private func buildDataset(scriptURL: URL, arguments: [String]) throws -> BuiltDatasetArtifacts {
        let repoRoot = repositoryRoot()
        let process = Process()
        let outputPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.currentDirectoryURL = repoRoot
        process.arguments = [scriptURL.path] + arguments
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            XCTFail(output)
            throw ValidationError.builderFailed
        }

        let outputDirectory = URL(fileURLWithPath: arguments.last ?? "", isDirectory: true)
        let snapshotURL = outputDirectory.appendingPathComponent("shelters.sqlite")
        let metadataURL = outputDirectory.appendingPathComponent("dataset-metadata.json")
        let metadataData = try Data(contentsOf: metadataURL)
        let metadata = try SyncCoding.decoder().decode(DatasetVersionResponseDTO.self, from: metadataData)

        return BuiltDatasetArtifacts(snapshotURL: snapshotURL, metadataURL: metadataURL, metadata: metadata)
    }

    private func count(in database: SQLiteDatabase, sql: String) throws -> Int {
        let rows = try database.query(sql)
        if rows.count == 1 {
            return Int(try XCTUnwrap(rows.first?.int64("value")))
        }
        return rows.count
    }

    private func sha256(for fileURL: URL) throws -> String {
        let data = try Data(contentsOf: fileURL)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func makeSandboxDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SheltersExternalSource-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return directory
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

private struct BuiltDatasetArtifacts {
    let snapshotURL: URL
    let metadataURL: URL
    let metadata: DatasetVersionResponseDTO
}

private enum ValidationError: Error {
    case builderFailed
}

private struct TestBeerShevaSheltersRawSnapshot: Decodable {
    let records: [TestBeerShevaShelterRawRecord]
}

private struct TestBeerShevaShelterRawRecord: Decodable {
    let name: String
    let latitude: Double
    let longitude: Double

    enum CodingKeys: String, CodingKey {
        case name
        case latitude = "lat"
        case longitude = "lon"
    }
}

private struct TestDedupeReviewReport: Decodable {
    let mergedCanonicalCount: Int
    let reviewCaseCount: Int
}

private func testHaversineDistanceMeters(
    latitudeA: Double,
    longitudeA: Double,
    latitudeB: Double,
    longitudeB: Double
) -> Double {
    let radius = 6_371_000.0
    let lat1 = latitudeA * .pi / 180
    let lat2 = latitudeB * .pi / 180
    let deltaLat = (latitudeB - latitudeA) * .pi / 180
    let deltaLon = (longitudeB - longitudeA) * .pi / 180
    let a = sin(deltaLat / 2) * sin(deltaLat / 2)
        + cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2)
    let c = 2 * atan2(sqrt(a), sqrt(1 - a))
    return radius * c
}
