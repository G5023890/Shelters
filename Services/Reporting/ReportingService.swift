import Foundation

protocol ReportingService: Sendable {
    func fetchPendingReports() async throws -> [UserReport]
    func fetchAllReports(limit: Int?) async throws -> [UserReport]
    func fetchReport(id: UUID) async throws -> UserReport?
    func fetchPhotoEvidence(for reportID: UUID) async throws -> [PhotoEvidence]
    func fetchPendingUploads() async throws -> [PendingUploadItem]
    func fetchUploads(for reportID: UUID) async throws -> [PendingUploadItem]
    func createPendingReport(from draft: UserReportDraft) async throws -> UserReport
    func preparePhotoDraft(from fileURL: URL) async throws -> PhotoEvidenceDraft
    func attachPreparedPhoto(_ draft: PhotoEvidenceDraft, to reportID: UUID) async throws -> PhotoEvidence
    func processPendingUploads() async throws -> ReportingUploadRunResult
    func retryUpload(for reportID: UUID) async throws -> ReportingUploadRunResult
}
