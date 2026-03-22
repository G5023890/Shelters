import CryptoKit
import Foundation
import XCTest
@testable import SheltersKit

final class NetlifySiteBundlePreparationTests: XCTestCase {
    func testPrepareNetlifySiteBundleRewritesMetadataForHostedDatasetURL() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let builderOutputDirectory = try makeSandboxDirectory(prefix: "SheltersBundleInput")
        let siteOutputDirectory = try makeSandboxDirectory(prefix: "SheltersBundleSite")

        try run(
            executableURL: URL(fileURLWithPath: "/bin/zsh"),
            arguments: [
                repoRoot.appendingPathComponent("Tools/DatasetBuilder/build_sample_dataset.sh").path,
                "--output-dir", builderOutputDirectory.path,
                "--download-base-url", "http://127.0.0.1:8999"
            ],
            currentDirectoryURL: repoRoot
        )

        try run(
            executableURL: URL(fileURLWithPath: "/bin/zsh"),
            arguments: [
                repoRoot.appendingPathComponent("Services/netlify-api/prepare_netlify_site_bundle.sh").path,
                "--input-dir", builderOutputDirectory.path,
                "--output-dir", siteOutputDirectory.path,
                "--site-url", "https://shelters-isr.netlify.app"
            ],
            currentDirectoryURL: repoRoot
        )

        let metadataURL = siteOutputDirectory.appendingPathComponent("dataset-metadata.json")
        let snapshotURL = siteOutputDirectory.appendingPathComponent("shelters.sqlite")
        let indexURL = siteOutputDirectory.appendingPathComponent("index.html")

        XCTAssertTrue(FileManager.default.fileExists(atPath: metadataURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: snapshotURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: indexURL.path))

        let metadata = try SyncCoding.decoder().decode(
            DatasetVersionResponseDTO.self,
            from: Data(contentsOf: metadataURL)
        )

        XCTAssertEqual(
            metadata.downloadURL.absoluteString,
            "https://shelters-isr.netlify.app/shelters.sqlite"
        )
        XCTAssertEqual(metadata.fileSize, try fileSize(at: snapshotURL))
        XCTAssertEqual(try sha256(for: snapshotURL), metadata.checksum)
    }

    private func run(
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
            throw NetlifySiteBundlePreparationError.processFailed
        }
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

    private func sha256(for fileURL: URL) throws -> String {
        let data = try Data(contentsOf: fileURL)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func fileSize(at fileURL: URL) throws -> Int {
        let values = try fileURL.resourceValues(forKeys: [.fileSizeKey])
        return try XCTUnwrap(values.fileSize)
    }
}

private enum NetlifySiteBundlePreparationError: Error {
    case processFailed
}
