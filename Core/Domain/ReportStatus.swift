import Foundation

enum ReportStatus: String, CaseIterable, Codable, Sendable {
    case draft
    case pendingUpload = "pending_upload"
    case uploading
    case uploaded
    case failed

    var localizationKey: L10n.Key {
        switch self {
        case .draft:
            return .reportStatusDraft
        case .pendingUpload:
            return .reportStatusPendingUpload
        case .uploading:
            return .reportStatusUploading
        case .uploaded:
            return .reportStatusUploaded
        case .failed:
            return .reportStatusFailed
        }
    }
}
