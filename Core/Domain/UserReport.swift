import Foundation

struct UserReport: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let canonicalPlaceID: UUID?
    let reportType: ReportType
    let reportStatus: ReportStatus
    let userCoordinate: GeoCoordinate?
    let suggestedEntranceCoordinate: GeoCoordinate?
    let textNote: String?
    let datasetVersion: String
    let localCreatedAt: Date
    let statusUpdatedAt: Date
    let uploadAttemptCount: Int
    let lastUploadAttemptAt: Date?
    let lastError: String?
    let uploadedAt: Date?

    var displayDatasetVersion: String? {
        datasetVersion == ReportingConstants.unavailableDatasetVersion ? nil : datasetVersion
    }

    var isActiveForUpload: Bool {
        switch reportStatus {
        case .draft, .pendingUpload, .uploading, .failed:
            return true
        case .uploaded:
            return false
        }
    }

    init(
        id: UUID,
        canonicalPlaceID: UUID?,
        reportType: ReportType,
        reportStatus: ReportStatus,
        userCoordinate: GeoCoordinate?,
        suggestedEntranceCoordinate: GeoCoordinate?,
        textNote: String?,
        datasetVersion: String,
        localCreatedAt: Date,
        statusUpdatedAt: Date? = nil,
        uploadAttemptCount: Int = 0,
        lastUploadAttemptAt: Date? = nil,
        lastError: String? = nil,
        uploadedAt: Date?
    ) {
        self.id = id
        self.canonicalPlaceID = canonicalPlaceID
        self.reportType = reportType
        self.reportStatus = reportStatus
        self.userCoordinate = userCoordinate
        self.suggestedEntranceCoordinate = suggestedEntranceCoordinate
        self.textNote = textNote
        self.datasetVersion = datasetVersion
        self.localCreatedAt = localCreatedAt
        self.statusUpdatedAt = statusUpdatedAt ?? localCreatedAt
        self.uploadAttemptCount = uploadAttemptCount
        self.lastUploadAttemptAt = lastUploadAttemptAt
        self.lastError = lastError
        self.uploadedAt = uploadedAt
    }
}
