import CryptoKit
import Foundation
import XCTest
@testable import SheltersKit

final class GitHubReleasePublicationWorkflowTests: XCTestCase {
    func testPublicationScriptPreparesGitHubLatestCompatibleArtifacts() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let builderOutputDirectory = try makeSandboxDirectory(prefix: "SheltersBuilderOutput")
        let publicationRootDirectory = try makeSandboxDirectory(prefix: "SheltersPublishedOutput")

        try runProcess(
            executableURL: URL(fileURLWithPath: "/bin/zsh"),
            arguments: [
                repoRoot.appendingPathComponent("Tools/DatasetBuilder/build_sample_dataset.sh").path,
                "--output-dir", builderOutputDirectory.path,
                "--download-base-url", "http://127.0.0.1:8999"
            ],
            currentDirectoryURL: repoRoot
        )

        try runProcess(
            executableURL: URL(fileURLWithPath: "/bin/zsh"),
            arguments: [
                repoRoot.appendingPathComponent("Tools/DatasetBuilder/publish_github_release_dataset.sh").path,
                "--input-dir", builderOutputDirectory.path,
                "--publish-dir", publicationRootDirectory.path,
                "--github-owner", "example-org",
                "--github-repo", "shelters-data"
            ],
            currentDirectoryURL: repoRoot
        )

        let sourceMetadataURL = builderOutputDirectory.appendingPathComponent("dataset-metadata.json")
        let sourceMetadata = try loadMetadata(at: sourceMetadataURL)

        let publishedDirectory = publicationRootDirectory.appendingPathComponent(sourceMetadata.datasetVersion)
        let publishedMetadataURL = publishedDirectory.appendingPathComponent("dataset-metadata.json")
        let publishedSnapshotURL = publishedDirectory.appendingPathComponent("shelters.sqlite")

        XCTAssertTrue(FileManager.default.fileExists(atPath: publishedMetadataURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: publishedSnapshotURL.path))

        let publishedMetadata = try loadMetadata(at: publishedMetadataURL)
        XCTAssertEqual(publishedMetadata.datasetVersion, sourceMetadata.datasetVersion)
        XCTAssertEqual(publishedMetadata.checksum, sourceMetadata.checksum)
        XCTAssertEqual(
            publishedMetadata.downloadURL.absoluteString,
            "https://github.com/example-org/shelters-data/releases/latest/download/shelters.sqlite"
        )
        XCTAssertEqual(
            publishedMetadata.fileSize,
            try fileSize(at: publishedSnapshotURL)
        )
        XCTAssertEqual(
            try sha256(for: publishedSnapshotURL),
            publishedMetadata.checksum
        )
    }

    func testResolveRecognizesGitHubLatestReleaseMetadataURLAsGitHubPublication() {
        let configuration = AppEnvironmentConfiguration.resolve(
            environment: [
                "SHELTERS_APP_ENVIRONMENT": "production",
                "SHELTERS_DATASET_METADATA_URL": "https://github.com/example-org/shelters-data/releases/latest/download/dataset-metadata.json"
            ]
        )

        XCTAssertEqual(configuration.environment, .production)
        XCTAssertEqual(configuration.datasetPublication?.sourceKind, .githubReleases)
        XCTAssertEqual(
            configuration.datasetPublication?.metadataURL.absoluteString,
            "https://github.com/example-org/shelters-data/releases/latest/download/dataset-metadata.json"
        )
    }

    private func loadMetadata(at fileURL: URL) throws -> DatasetVersionResponseDTO {
        let data = try Data(contentsOf: fileURL)
        return try SyncCoding.decoder().decode(DatasetVersionResponseDTO.self, from: data)
    }

    private func sha256(for fileURL: URL) throws -> String {
        let data = try Data(contentsOf: fileURL)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func fileSize(at fileURL: URL) throws -> Int {
        let values = try fileURL.resourceValues(forKeys: [.fileSizeKey])
        return try XCTUnwrap(values.fileSize)
    }

    private func makeSandboxDirectory(prefix: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return directory
    }

    private func runProcess(
        executableURL: URL,
        arguments: [String],
        currentDirectoryURL: URL
    ) throws {
        let process = Process()
        let outputPipe = Pipe()
        process.executableURL = executableURL
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectoryURL
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()
        process.waitUntilExit()

        let output = String(
            data: outputPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""

        guard process.terminationStatus == 0 else {
            XCTFail(output)
            throw PublicationWorkflowValidationError.processFailed
        }
    }
}

private enum PublicationWorkflowValidationError: Error {
    case processFailed
}
