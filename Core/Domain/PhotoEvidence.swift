import Foundation

struct PhotoEvidence: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let reportID: UUID
    let localFilePath: String
    let exifCoordinate: GeoCoordinate?
    let capturedAt: Date?
    let hasMetadata: Bool
    let checksum: String?
    let createdAt: Date

    init(
        id: UUID,
        reportID: UUID,
        localFilePath: String,
        exifCoordinate: GeoCoordinate?,
        capturedAt: Date?,
        hasMetadata: Bool,
        checksum: String?,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.reportID = reportID
        self.localFilePath = localFilePath
        self.exifCoordinate = exifCoordinate
        self.capturedAt = capturedAt
        self.hasMetadata = hasMetadata
        self.checksum = checksum
        self.createdAt = createdAt
    }
}
