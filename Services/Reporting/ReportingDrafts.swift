import Foundation

enum ReportingConstants {
    static let unavailableDatasetVersion = "unavailable"
}

struct UserReportDraft: Sendable {
    let canonicalPlaceID: UUID?
    let reportType: ReportType
    let userCoordinate: GeoCoordinate?
    let suggestedEntranceCoordinate: GeoCoordinate?
    let textNote: String?
    let datasetVersion: String
}

struct PhotoEvidenceDraft: Sendable {
    let localFilePath: String
    let exifCoordinate: GeoCoordinate?
    let capturedAt: Date?
    let checksum: String?
}
