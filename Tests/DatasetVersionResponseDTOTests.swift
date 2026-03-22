import Foundation
import XCTest
@testable import SheltersKit

final class DatasetVersionResponseDTOTests: XCTestCase {
    func testDecodesRemoteDatasetVersionPayload() throws {
        let json = """
        {
          "datasetVersion": "2026.03.12-01",
          "publishedAt": "2026-03-12T18:00:00.000Z",
          "buildNumber": 42,
          "checksum": "abc123",
          "downloadURL": "https://example.com/shelters.sqlite",
          "schemaVersion": 1,
          "minimumClientVersion": "1.0.0",
          "fileSize": 1024,
          "recordCount": 55
        }
        """

        let data = try XCTUnwrap(json.data(using: .utf8))
        let dto = try SyncCoding.decoder().decode(DatasetVersionResponseDTO.self, from: data)

        XCTAssertEqual(dto.datasetVersion, "2026.03.12-01")
        XCTAssertEqual(dto.buildNumber, 42)
        XCTAssertEqual(dto.schemaVersion, 1)
        XCTAssertEqual(dto.fileSize, 1024)
        XCTAssertEqual(dto.recordCount, 55)
        XCTAssertEqual(dto.downloadURL.absoluteString, "https://example.com/shelters.sqlite")
    }
}
