import Foundation

enum ReportingPublicationContract {
    static let reportsPath = "reports"
    static let reportPhotosPath = "reports/photo"

    static let requiredReportFields = [
        "localReportID",
        "canonicalPlaceID",
        "reportType",
        "datasetVersion",
        "textNote",
        "userLat",
        "userLon",
        "suggestedEntranceLat",
        "suggestedEntranceLon",
        "localCreatedAt"
    ]

    static let requiredPhotoFields = [
        "localPhotoID",
        "localReportID",
        "remoteReportID",
        "localFilePath",
        "checksum",
        "exifLat",
        "exifLon",
        "capturedAt",
        "hasMetadata"
    ]
}
