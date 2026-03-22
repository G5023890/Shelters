import Foundation

struct ExtractedPhotoMetadata: Hashable, Sendable {
    let exifCoordinate: GeoCoordinate?
    let capturedAt: Date?

    var hasMetadata: Bool {
        exifCoordinate != nil || capturedAt != nil
    }
}

protocol PhotoMetadataExtracting: Sendable {
    func extractMetadata(from fileURL: URL) async throws -> ExtractedPhotoMetadata
}

protocol PhotoEvidenceFileStoring: Sendable {
    func storePhoto(from originalFileURL: URL) throws -> URL
}

protocol PhotoEvidenceDraftPreparing: Sendable {
    func prepareDraft(from fileURL: URL) async throws -> PhotoEvidenceDraft
}
