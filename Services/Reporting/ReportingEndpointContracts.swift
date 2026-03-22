import Foundation

struct ReportUploadRequestDTO: Codable, Sendable {
    let localReportID: UUID
    let canonicalPlaceID: UUID?
    let reportType: String
    let datasetVersion: String
    let textNote: String?
    let userLat: Double?
    let userLon: Double?
    let suggestedEntranceLat: Double?
    let suggestedEntranceLon: Double?
    let localCreatedAt: Date

    init(payload: ReportUploadPayload) {
        localReportID = payload.localReportID
        canonicalPlaceID = payload.canonicalPlaceID
        reportType = payload.reportType.rawValue
        datasetVersion = payload.datasetVersion
        textNote = payload.textNote
        userLat = payload.userCoordinate?.latitude
        userLon = payload.userCoordinate?.longitude
        suggestedEntranceLat = payload.suggestedEntranceCoordinate?.latitude
        suggestedEntranceLon = payload.suggestedEntranceCoordinate?.longitude
        localCreatedAt = payload.localCreatedAt
    }
}

struct ReportUploadResponseDTO: Codable, Sendable {
    let remoteReportID: String?
    let status: String?
}

struct PhotoEvidenceUploadRequestDTO: Codable, Sendable {
    let localPhotoID: UUID
    let localReportID: UUID
    let remoteReportID: String?
    let localFilePath: String
    let checksum: String?
    let exifLat: Double?
    let exifLon: Double?
    let capturedAt: Date?
    let hasMetadata: Bool

    init(payload: PhotoEvidenceUploadPayload, reportReceipt: UploadedReportReceipt) {
        localPhotoID = payload.localPhotoID
        localReportID = payload.localReportID
        remoteReportID = reportReceipt.remoteReportID
        localFilePath = payload.localFilePath
        checksum = payload.checksum
        exifLat = payload.exifCoordinate?.latitude
        exifLon = payload.exifCoordinate?.longitude
        capturedAt = payload.capturedAt
        hasMetadata = payload.hasMetadata
    }
}

struct PhotoEvidenceUploadResponseDTO: Codable, Sendable {
    let status: String?
}
