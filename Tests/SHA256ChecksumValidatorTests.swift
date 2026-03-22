import Foundation
import XCTest
@testable import SheltersKit

final class SHA256ChecksumValidatorTests: XCTestCase {
    func testValidatesKnownChecksum() async throws {
        let fileManager = FileManager.default
        let fileURL = fileManager.temporaryDirectory.appendingPathComponent("checksum-test-\(UUID().uuidString).txt")
        let data = try XCTUnwrap("hello".data(using: .utf8))
        try data.write(to: fileURL)

        defer {
            try? fileManager.removeItem(at: fileURL)
        }

        let checksum = try await SHA256DatasetChecksumValidator().validate(
            fileAt: fileURL,
            expectedChecksum: "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
        )

        XCTAssertEqual(checksum, "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
    }
}
