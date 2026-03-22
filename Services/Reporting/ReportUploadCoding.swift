import Foundation

enum ReportingLifecycle {
    static func reportPayload(from report: UserReport) -> ReportUploadPayload {
        ReportUploadPayload(
            localReportID: report.id,
            canonicalPlaceID: report.canonicalPlaceID,
            reportType: report.reportType,
            datasetVersion: report.datasetVersion,
            textNote: report.textNote,
            userCoordinate: report.userCoordinate,
            suggestedEntranceCoordinate: report.suggestedEntranceCoordinate,
            localCreatedAt: report.localCreatedAt
        )
    }

    static func photoPayload(from photo: PhotoEvidence) -> PhotoEvidenceUploadPayload {
        PhotoEvidenceUploadPayload(
            localPhotoID: photo.id,
            localReportID: photo.reportID,
            localFilePath: photo.localFilePath,
            checksum: photo.checksum,
            exifCoordinate: photo.exifCoordinate,
            capturedAt: photo.capturedAt,
            hasMetadata: photo.hasMetadata
        )
    }
}
