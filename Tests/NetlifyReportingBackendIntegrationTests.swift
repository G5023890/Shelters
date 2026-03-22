import Foundation
import XCTest
@testable import SheltersKit

final class NetlifyReportingBackendIntegrationTests: XCTestCase {
    func testLocalNetlifyBackendAcceptsReportAndPhotoUploadsThroughCurrentTransport() async throws {
        try requireNode()

        let port = try makeAvailablePort()
        let sandbox = try makeSandboxDirectory()
        let process = try startLocalReportingBackend(port: port, storageDirectoryURL: sandbox)
        addTeardownBlock {
            terminateReportingBackendProcess(process)
        }

        try await waitForBackend(at: URL(string: "http://127.0.0.1:\(port)/health")!)

        let localReportID = UUID(uuidString: "F9543357-5A58-4F0A-8FF3-E43AA54487B2")!
        let localPhotoID = UUID(uuidString: "8E165BAE-BEB0-4AC4-8992-26A322CCDFB0")!
        let transport = URLSessionReportUploadTransport(
            configuration: ReportingAPIConfiguration(
                sourceKind: .netlifyFunctions,
                reportsURL: URL(string: "http://127.0.0.1:\(port)/.netlify/functions/reports")!,
                reportPhotosURL: URL(string: "http://127.0.0.1:\(port)/.netlify/functions/reports/photo")!
            ),
            session: URLSession(configuration: .ephemeral)
        )

        let receipt = try await transport.uploadReport(
            ReportUploadPayload(
                localReportID: localReportID,
                canonicalPlaceID: nil,
                reportType: .movedEntrance,
                datasetVersion: "2026.03.13-01",
                textNote: "Entrance marker moved to the east side",
                userCoordinate: GeoCoordinate(latitude: 31.2529, longitude: 34.7915),
                suggestedEntranceCoordinate: GeoCoordinate(latitude: 31.2531, longitude: 34.7918),
                localCreatedAt: Date(timeIntervalSince1970: 1_742_000_000)
            )
        )

        XCTAssertEqual(receipt.remoteReportID, "dev-report-\(localReportID.uuidString)")

        try await transport.uploadPhotoEvidence(
            PhotoEvidenceUploadPayload(
                localPhotoID: localPhotoID,
                localReportID: localReportID,
                localFilePath: "/tmp/report-photo.jpg",
                checksum: "sha256-photo",
                exifCoordinate: GeoCoordinate(latitude: 31.2530, longitude: 34.7917),
                capturedAt: Date(timeIntervalSince1970: 1_742_000_120),
                hasMetadata: true
            ),
            reportReceipt: receipt
        )

        let storedReport = try loadJSON(
            at: sandbox
                .appendingPathComponent("reports", isDirectory: true)
                .appendingPathComponent("\(localReportID.uuidString).json")
        )
        let storedPhoto = try loadJSON(
            at: sandbox
                .appendingPathComponent("photos", isDirectory: true)
                .appendingPathComponent("\(localPhotoID.uuidString).json")
        )

        XCTAssertEqual(storedReport["remoteReportID"] as? String, "dev-report-\(localReportID.uuidString)")
        XCTAssertEqual(storedReport["status"] as? String, "accepted")
        XCTAssertEqual(storedPhoto["remoteReportID"] as? String, "dev-report-\(localReportID.uuidString)")
        XCTAssertEqual(storedPhoto["status"] as? String, "accepted")
    }

    func testLocalNetlifyBackendRejectsPhotoUploadWithoutMatchingReport() async throws {
        try requireNode()

        let port = try makeAvailablePort()
        let sandbox = try makeSandboxDirectory()
        let process = try startLocalReportingBackend(port: port, storageDirectoryURL: sandbox)
        addTeardownBlock {
            terminateReportingBackendProcess(process)
        }

        try await waitForBackend(at: URL(string: "http://127.0.0.1:\(port)/health")!)

        let transport = URLSessionReportUploadTransport(
            configuration: ReportingAPIConfiguration(
                sourceKind: .netlifyFunctions,
                reportsURL: URL(string: "http://127.0.0.1:\(port)/.netlify/functions/reports")!,
                reportPhotosURL: URL(string: "http://127.0.0.1:\(port)/.netlify/functions/reports/photo")!
            ),
            session: URLSession(configuration: .ephemeral)
        )

        do {
            try await transport.uploadPhotoEvidence(
                PhotoEvidenceUploadPayload(
                    localPhotoID: UUID(),
                    localReportID: UUID(),
                    localFilePath: "/tmp/report-photo.jpg",
                    checksum: nil,
                    exifCoordinate: nil,
                    capturedAt: nil,
                    hasMetadata: false
                ),
                reportReceipt: UploadedReportReceipt(remoteReportID: nil)
            )
            XCTFail("Expected photo upload to fail when no report exists on the backend")
        } catch let error as ReportingUploadError {
            guard case .invalidResponseStatus(let statusCode) = error else {
                XCTFail("Unexpected error: \(error)")
                return
            }
            XCTAssertEqual(statusCode, 404)
        }
    }

    private func startLocalReportingBackend(port: UInt16, storageDirectoryURL: URL) throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.currentDirectoryURL = URL(fileURLWithPath: "/Users/grigorymordokhovich/Documents/Develop/Shelters")
        process.arguments = [
            "node",
            "services/netlify-api/dev-server.js",
            "--port",
            String(port),
            "--data-dir",
            storageDirectoryURL.path
        ]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        return process
    }

    private func waitForBackend(at url: URL) async throws {
        let session = URLSession(configuration: .ephemeral)
        for _ in 0..<20 {
            do {
                let (_, response) = try await session.data(from: url)
                if let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) {
                    return
                }
            } catch {
                try await Task.sleep(nanoseconds: 150_000_000)
            }
        }

        XCTFail("Local reporting backend did not become ready at \(url.absoluteString)")
    }

    private func requireNode() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["node", "--version"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw XCTSkip("Node.js is required for local backend integration tests.")
        }

        if process.terminationStatus != 0 {
            throw XCTSkip("Node.js is required for local backend integration tests.")
        }
    }

    private func loadJSON(at fileURL: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: fileURL)
        let value = try JSONSerialization.jsonObject(with: data)
        return try XCTUnwrap(value as? [String: Any])
    }

    private func makeSandboxDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SheltersReportingBackend-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return directory
    }
    private func makeAvailablePort() throws -> UInt16 {
        #if canImport(Darwin)
        let socketDescriptor = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard socketDescriptor >= 0 else {
            throw NetlifyReportingBackendIntegrationError.unableToAllocatePort
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
            throw NetlifyReportingBackendIntegrationError.unableToAllocatePort
        }

        var boundAddress = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &boundAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.getsockname(socketDescriptor, $0, &length)
            }
        }
        guard nameResult == 0 else {
            throw NetlifyReportingBackendIntegrationError.unableToAllocatePort
        }

        return UInt16(bigEndian: boundAddress.sin_port)
        #else
        throw NetlifyReportingBackendIntegrationError.unableToAllocatePort
        #endif
    }
}

private enum NetlifyReportingBackendIntegrationError: LocalizedError {
    case unableToAllocatePort
}

private func terminateReportingBackendProcess(_ process: Process) {
    guard process.isRunning else { return }
    process.terminate()
    process.waitUntilExit()
}
