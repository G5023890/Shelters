import CryptoKit
import Foundation

final class DefaultPhotoEvidenceDraftPreparer: PhotoEvidenceDraftPreparing {
    private let metadataExtractor: PhotoMetadataExtracting
    private let fileStore: PhotoEvidenceFileStoring

    init(
        metadataExtractor: PhotoMetadataExtracting,
        fileStore: PhotoEvidenceFileStoring
    ) {
        self.metadataExtractor = metadataExtractor
        self.fileStore = fileStore
    }

    func prepareDraft(from fileURL: URL) async throws -> PhotoEvidenceDraft {
        let storedFileURL = try fileStore.storePhoto(from: fileURL)

        do {
            let metadata = try await metadataExtractor.extractMetadata(from: storedFileURL)
            let checksum = try sha256(for: storedFileURL)

            return PhotoEvidenceDraft(
                localFilePath: storedFileURL.path,
                exifCoordinate: metadata.exifCoordinate,
                capturedAt: metadata.capturedAt,
                checksum: checksum
            )
        } catch {
            try? FileManager.default.removeItem(at: storedFileURL)
            throw error
        }
    }

    private func sha256(for fileURL: URL) throws -> String {
        let data = try Data(contentsOf: fileURL)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
