import Foundation
import XCTest
@testable import SheltersKit

final class URLSessionReportUploadTransportTests: XCTestCase {
    override func setUp() {
        super.setUp()
        StubURLProtocol.requestHandler = nil
    }

    func testUploadReportPostsJSONToConfiguredReportsEndpoint() async throws {
        let expectedURL = URL(string: "https://example.netlify.app/.netlify/functions/reports")!
        let expectedRemoteID = "remote-123"

        StubURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url, expectedURL)
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

            let body = try XCTUnwrap(request.bodyData)
            let payload = try ReportingTransportCoding.decoder().decode(ReportUploadRequestDTO.self, from: body)
            XCTAssertEqual(payload.localReportID.uuidString, "1D857E52-5480-4FA6-BB43-95E430E0866C")
            XCTAssertEqual(payload.reportType, ReportType.confirmLocation.rawValue)
            XCTAssertEqual(payload.datasetVersion, "2026.03.13")

            let response = HTTPURLResponse(url: expectedURL, statusCode: 202, httpVersion: nil, headerFields: nil)!
            let data = try ReportingTransportCoding.encoder().encode(
                ReportUploadResponseDTO(remoteReportID: expectedRemoteID, status: "accepted")
            )
            return (response, data)
        }

        let transport = makeTransport()
        let receipt = try await transport.uploadReport(
            ReportUploadPayload(
                localReportID: UUID(uuidString: "1D857E52-5480-4FA6-BB43-95E430E0866C")!,
                canonicalPlaceID: nil,
                reportType: .confirmLocation,
                datasetVersion: "2026.03.13",
                textNote: "Confirmed on site",
                userCoordinate: GeoCoordinate(latitude: 32.0853, longitude: 34.7818),
                suggestedEntranceCoordinate: nil,
                localCreatedAt: Date(timeIntervalSince1970: 1_742_000_000)
            )
        )

        XCTAssertEqual(receipt.remoteReportID, expectedRemoteID)
    }

    func testUploadPhotoEvidencePostsJSONToConfiguredPhotosEndpoint() async throws {
        let expectedURL = URL(string: "https://example.netlify.app/.netlify/functions/reports/photo")!

        StubURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url, expectedURL)
            XCTAssertEqual(request.httpMethod, "POST")

            let body = try XCTUnwrap(request.bodyData)
            let payload = try ReportingTransportCoding.decoder().decode(PhotoEvidenceUploadRequestDTO.self, from: body)
            XCTAssertEqual(payload.remoteReportID, "remote-123")
            XCTAssertEqual(payload.checksum, "sha256-photo")
            XCTAssertTrue(payload.hasMetadata)

            let response = HTTPURLResponse(url: expectedURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = try ReportingTransportCoding.encoder().encode(
                PhotoEvidenceUploadResponseDTO(status: "accepted")
            )
            return (response, data)
        }

        let transport = makeTransport()
        try await transport.uploadPhotoEvidence(
            PhotoEvidenceUploadPayload(
                localPhotoID: UUID(uuidString: "F08CFBF1-B9A2-460B-B345-56DEDD2D1C5A")!,
                localReportID: UUID(uuidString: "1D857E52-5480-4FA6-BB43-95E430E0866C")!,
                localFilePath: "/tmp/report.jpg",
                checksum: "sha256-photo",
                exifCoordinate: GeoCoordinate(latitude: 32.08, longitude: 34.78),
                capturedAt: Date(timeIntervalSince1970: 1_742_000_100),
                hasMetadata: true
            ),
            reportReceipt: UploadedReportReceipt(remoteReportID: "remote-123")
        )
    }

    func testUploadReportFailsForNon2xxStatus() async {
        let expectedURL = URL(string: "https://example.netlify.app/.netlify/functions/reports")!

        StubURLProtocol.requestHandler = { _ in
            let response = HTTPURLResponse(url: expectedURL, statusCode: 503, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let transport = makeTransport()

        do {
            _ = try await transport.uploadReport(
                ReportUploadPayload(
                    localReportID: UUID(),
                    canonicalPlaceID: nil,
                    reportType: .wrongLocation,
                    datasetVersion: "2026.03.13",
                    textNote: nil,
                    userCoordinate: nil,
                    suggestedEntranceCoordinate: nil,
                    localCreatedAt: Date()
                )
            )
            XCTFail("Expected transport to fail for 503 response")
        } catch let error as ReportingUploadError {
            guard case .invalidResponseStatus(let code) = error else {
                XCTFail("Unexpected error: \(error)")
                return
            }
            XCTAssertEqual(code, 503)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeTransport() -> URLSessionReportUploadTransport {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]

        return URLSessionReportUploadTransport(
            configuration: ReportingAPIConfiguration(
                sourceKind: .netlifyFunctions,
                reportsURL: URL(string: "https://example.netlify.app/.netlify/functions/reports")!,
                reportPhotosURL: URL(string: "https://example.netlify.app/.netlify/functions/reports/photo")!
            ),
            session: URLSession(configuration: configuration)
        )
    }
}

private final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = StubURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private extension URLRequest {
    var bodyData: Data? {
        if let httpBody {
            return httpBody
        }

        guard let stream = httpBodyStream else {
            return nil
        }

        stream.open()
        defer { stream.close() }

        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        var data = Data()
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            guard read > 0 else {
                break
            }
            data.append(buffer, count: read)
        }

        return data.isEmpty ? nil : data
    }
}
