import CryptoKit
import Foundation

protocol DatasetChecksumValidating: Sendable {
    func validate(fileAt fileURL: URL, expectedChecksum: String) async throws -> String
}

enum DatasetChecksumValidationError: LocalizedError {
    case fileReadFailed
    case checksumMismatch(expected: String, actual: String)

    var errorDescription: String? {
        switch self {
        case .fileReadFailed:
            return "Dataset checksum validation could not read the downloaded file."
        case .checksumMismatch(let expected, let actual):
            return "Dataset checksum mismatch. Expected \(expected), got \(actual)."
        }
    }
}

struct SHA256DatasetChecksumValidator: DatasetChecksumValidating {
    func validate(fileAt fileURL: URL, expectedChecksum: String) async throws -> String {
        let data: Data

        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw DatasetChecksumValidationError.fileReadFailed
        }

        let digest = SHA256.hash(data: data)
        let actualChecksum = digest.map { String(format: "%02x", $0) }.joined()
        let normalizedExpectedChecksum = expectedChecksum.lowercased()

        guard actualChecksum == normalizedExpectedChecksum else {
            throw DatasetChecksumValidationError.checksumMismatch(
                expected: normalizedExpectedChecksum,
                actual: actualChecksum
            )
        }

        return actualChecksum
    }
}

