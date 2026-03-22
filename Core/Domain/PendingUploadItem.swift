import Foundation

enum PendingUploadEntityType: String, CaseIterable, Codable, Sendable {
    case userReport = "user_report"
    case photoEvidence = "photo_evidence"

    var localizationKey: L10n.Key {
        switch self {
        case .userReport:
            return .reportingUploadEntityReport
        case .photoEvidence:
            return .reportingUploadEntityPhoto
        }
    }
}

enum PendingUploadState: String, CaseIterable, Codable, Sendable {
    case pendingUpload = "pending_upload"
    case uploading
    case failed
    case uploaded

    var localizationKey: L10n.Key {
        switch self {
        case .pendingUpload:
            return .reportingUploadStatePendingUpload
        case .uploading:
            return .reportingUploadStateUploading
        case .failed:
            return .reportingUploadStateFailed
        case .uploaded:
            return .reportingUploadStateUploaded
        }
    }
}

struct PendingUploadItem: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let entityType: PendingUploadEntityType
    let entityID: String
    let reportID: UUID
    let uploadState: PendingUploadState
    let lastError: String?
    let attemptCount: Int
    let lastAttemptAt: Date?
    let completedAt: Date?
    let createdAt: Date
    let updatedAt: Date

    init(
        id: UUID,
        entityType: PendingUploadEntityType,
        entityID: String,
        reportID: UUID? = nil,
        uploadState: PendingUploadState,
        lastError: String?,
        attemptCount: Int = 0,
        lastAttemptAt: Date? = nil,
        completedAt: Date? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.entityType = entityType
        self.entityID = entityID
        self.reportID = reportID ?? UUID(uuidString: entityID) ?? UUID()
        self.uploadState = uploadState
        self.lastError = lastError
        self.attemptCount = attemptCount
        self.lastAttemptAt = lastAttemptAt
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
