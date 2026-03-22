import Foundation

final class LocalReportingService: ReportingService {
    private let userReportRepository: UserReportRepository
    private let photoEvidenceRepository: PhotoEvidenceRepository
    private let pendingUploadRepository: PendingUploadRepository
    private let photoEvidenceDraftPreparer: PhotoEvidenceDraftPreparing
    private let uploadTransport: ReportUploadTransport
    private let now: @Sendable () -> Date

    init(
        userReportRepository: UserReportRepository,
        photoEvidenceRepository: PhotoEvidenceRepository,
        pendingUploadRepository: PendingUploadRepository,
        photoEvidenceDraftPreparer: PhotoEvidenceDraftPreparing,
        uploadTransport: ReportUploadTransport = UnavailableReportUploadTransport(),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.userReportRepository = userReportRepository
        self.photoEvidenceRepository = photoEvidenceRepository
        self.pendingUploadRepository = pendingUploadRepository
        self.photoEvidenceDraftPreparer = photoEvidenceDraftPreparer
        self.uploadTransport = uploadTransport
        self.now = now
    }

    func fetchPendingReports() async throws -> [UserReport] {
        try userReportRepository.fetchPendingReports()
    }

    func fetchAllReports(limit: Int?) async throws -> [UserReport] {
        try userReportRepository.fetchAll(limit: limit)
    }

    func fetchReport(id: UUID) async throws -> UserReport? {
        try userReportRepository.fetch(id: id)
    }

    func fetchPhotoEvidence(for reportID: UUID) async throws -> [PhotoEvidence] {
        try photoEvidenceRepository.fetchPhotoEvidence(for: reportID)
    }

    func fetchPendingUploads() async throws -> [PendingUploadItem] {
        try pendingUploadRepository.fetchPendingUploads()
    }

    func fetchUploads(for reportID: UUID) async throws -> [PendingUploadItem] {
        try pendingUploadRepository.fetchUploads(for: reportID)
    }

    func createPendingReport(from draft: UserReportDraft) async throws -> UserReport {
        let createdAt = now()
        let draftReport = UserReport(
            id: UUID(),
            canonicalPlaceID: draft.canonicalPlaceID,
            reportType: draft.reportType,
            reportStatus: .draft,
            userCoordinate: draft.userCoordinate,
            suggestedEntranceCoordinate: draft.suggestedEntranceCoordinate,
            textNote: draft.textNote,
            datasetVersion: draft.datasetVersion,
            localCreatedAt: createdAt,
            statusUpdatedAt: createdAt,
            uploadAttemptCount: 0,
            lastUploadAttemptAt: nil,
            lastError: nil,
            uploadedAt: nil
        )

        try userReportRepository.save(draftReport)

        let queuedReport = transitionReport(
            draftReport,
            to: .pendingUpload,
            lastError: nil,
            uploadedAt: nil,
            incrementAttemptCount: false
        )
        let reportUpload = makeUploadItem(
            id: UUID(),
            entityType: .userReport,
            entityID: queuedReport.id.uuidString,
            reportID: queuedReport.id,
            state: .pendingUpload,
            lastError: nil,
            attemptCount: 0,
            lastAttemptAt: nil,
            completedAt: nil,
            createdAt: queuedReport.localCreatedAt,
            updatedAt: queuedReport.statusUpdatedAt
        )

        try userReportRepository.save(queuedReport)
        try pendingUploadRepository.save(reportUpload)

        return queuedReport
    }

    func preparePhotoDraft(from fileURL: URL) async throws -> PhotoEvidenceDraft {
        try await photoEvidenceDraftPreparer.prepareDraft(from: fileURL)
    }

    func attachPreparedPhoto(_ draft: PhotoEvidenceDraft, to reportID: UUID) async throws -> PhotoEvidence {
        guard let report = try userReportRepository.fetch(id: reportID) else {
            throw ReportingUploadError.reportNotFound
        }

        let createdAt = now()
        let photoEvidence = PhotoEvidence(
            id: UUID(),
            reportID: reportID,
            localFilePath: draft.localFilePath,
            exifCoordinate: draft.exifCoordinate,
            capturedAt: draft.capturedAt,
            hasMetadata: draft.exifCoordinate != nil || draft.capturedAt != nil || draft.checksum != nil,
            checksum: draft.checksum,
            createdAt: createdAt
        )
        let photoUpload = makeUploadItem(
            id: UUID(),
            entityType: .photoEvidence,
            entityID: photoEvidence.id.uuidString,
            reportID: reportID,
            state: .pendingUpload,
            lastError: nil,
            attemptCount: 0,
            lastAttemptAt: nil,
            completedAt: nil,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let updatedReport = transitionReport(
            report,
            to: .pendingUpload,
            lastError: nil,
            uploadedAt: nil,
            incrementAttemptCount: false
        )

        try photoEvidenceRepository.save(photoEvidence)
        try pendingUploadRepository.save(photoUpload)
        try userReportRepository.save(updatedReport)
        try upsertReportUploadItem(for: updatedReport, createdAt: updatedReport.localCreatedAt)

        return photoEvidence
    }

    func processPendingUploads() async throws -> ReportingUploadRunResult {
        let reports = try userReportRepository.fetchPendingReports()
        guard !reports.isEmpty else {
            return .empty
        }

        var processed: [UUID] = []
        var succeeded: [UUID] = []
        var failed: [UUID] = []

        for report in reports where report.reportStatus != .draft {
            processed.append(report.id)

            do {
                try await processUpload(for: report.id)
                succeeded.append(report.id)
            } catch {
                failed.append(report.id)
            }
        }

        return ReportingUploadRunResult(
            processedReportIDs: processed,
            succeededReportIDs: succeeded,
            failedReportIDs: failed
        )
    }

    func retryUpload(for reportID: UUID) async throws -> ReportingUploadRunResult {
        guard let report = try userReportRepository.fetch(id: reportID) else {
            throw ReportingUploadError.reportNotFound
        }

        let uploads = try pendingUploadRepository.fetchUploads(for: reportID)
        let retriableUploads = uploads.filter { $0.uploadState == .failed || $0.uploadState == .pendingUpload }
        guard !retriableUploads.isEmpty || report.reportStatus == .failed else {
            throw ReportingUploadError.invalidReportState
        }

        let requeuedReport = transitionReport(
            report,
            to: .pendingUpload,
            lastError: nil,
            uploadedAt: nil,
            incrementAttemptCount: false
        )

        try userReportRepository.save(requeuedReport)

        for upload in uploads where upload.uploadState != .uploaded {
            try pendingUploadRepository.save(
                updateUploadItem(
                    upload,
                    state: .pendingUpload,
                    lastError: nil,
                    lastAttemptAt: upload.lastAttemptAt,
                    completedAt: nil,
                    incrementAttemptCount: false
                )
            )
        }
        try upsertReportUploadItem(for: requeuedReport, createdAt: requeuedReport.localCreatedAt)

        do {
            try await processUpload(for: reportID)
            return ReportingUploadRunResult(
                processedReportIDs: [reportID],
                succeededReportIDs: [reportID],
                failedReportIDs: []
            )
        } catch {
            return ReportingUploadRunResult(
                processedReportIDs: [reportID],
                succeededReportIDs: [],
                failedReportIDs: [reportID]
            )
        }
    }

    private func processUpload(for reportID: UUID) async throws {
        guard let currentReport = try userReportRepository.fetch(id: reportID) else {
            throw ReportingUploadError.reportNotFound
        }

        let uploads = try pendingUploadRepository.fetchUploads(for: reportID)
        let photoUploads = uploads
            .filter { $0.entityType == .photoEvidence && $0.uploadState != .uploaded }
            .sorted { $0.createdAt < $1.createdAt }

        let uploadStart = now()
        let uploadingReport = transitionReport(
            currentReport,
            to: .uploading,
            lastError: nil,
            uploadedAt: nil,
            incrementAttemptCount: true,
            lastUploadAttemptAt: uploadStart
        )
        let reportUpload = try pendingUploadRepository.fetch(entityType: .userReport, entityID: reportID.uuidString)
            ?? makeUploadItem(
                id: UUID(),
                entityType: .userReport,
                entityID: reportID.uuidString,
                reportID: reportID,
                state: .pendingUpload,
                lastError: nil,
                attemptCount: 0,
                lastAttemptAt: nil,
                completedAt: nil,
                createdAt: currentReport.localCreatedAt,
                updatedAt: currentReport.statusUpdatedAt
            )

        try userReportRepository.save(uploadingReport)
        let uploadingReportUpload = updateUploadItem(
            reportUpload,
            state: .uploading,
            lastError: nil,
            lastAttemptAt: uploadStart,
            completedAt: nil,
            incrementAttemptCount: true
        )
        try pendingUploadRepository.save(uploadingReportUpload)

        var uploadingPhotoUploads: [UUID: PendingUploadItem] = [:]
        for upload in photoUploads {
            let uploadingPhotoUpload = updateUploadItem(
                upload,
                state: .uploading,
                lastError: nil,
                lastAttemptAt: uploadStart,
                completedAt: nil,
                incrementAttemptCount: true
            )
            uploadingPhotoUploads[upload.id] = uploadingPhotoUpload
            try pendingUploadRepository.save(uploadingPhotoUpload)
        }

        do {
            let receipt = try await uploadTransport.uploadReport(ReportingLifecycle.reportPayload(from: uploadingReport))

            for photoUpload in photoUploads {
                guard let photoID = UUID(uuidString: photoUpload.entityID) else {
                    throw ReportingUploadError.photoEvidenceNotFound
                }
                guard let photo = try photoEvidenceRepository.fetch(id: photoID) else {
                    throw ReportingUploadError.photoEvidenceNotFound
                }
                let activePhotoUpload = uploadingPhotoUploads[photoUpload.id] ?? photoUpload

                try await uploadTransport.uploadPhotoEvidence(
                    ReportingLifecycle.photoPayload(from: photo),
                    reportReceipt: receipt
                )

                try pendingUploadRepository.save(
                    updateUploadItem(
                        activePhotoUpload,
                        state: .uploaded,
                        lastError: nil,
                        lastAttemptAt: now(),
                        completedAt: now(),
                        incrementAttemptCount: false
                    )
                )
            }

            let completedAt = now()
            try userReportRepository.save(
                transitionReport(
                    uploadingReport,
                    to: .uploaded,
                    lastError: nil,
                    uploadedAt: completedAt,
                    incrementAttemptCount: false
                )
            )
            try pendingUploadRepository.save(
                updateUploadItem(
                    uploadingReportUpload,
                    state: .uploaded,
                    lastError: nil,
                    lastAttemptAt: completedAt,
                    completedAt: completedAt,
                    incrementAttemptCount: false
                )
            )
        } catch {
            let failureReason = error.localizedDescription
            let failedAt = now()

            try userReportRepository.save(
                transitionReport(
                    uploadingReport,
                    to: .failed,
                    lastError: failureReason,
                    uploadedAt: nil,
                    incrementAttemptCount: false
                )
            )
            try pendingUploadRepository.save(
                updateUploadItem(
                    uploadingReportUpload,
                    state: .failed,
                    lastError: failureReason,
                    lastAttemptAt: failedAt,
                    completedAt: nil,
                    incrementAttemptCount: false
                )
            )

            for upload in photoUploads {
                if let latestUpload = try pendingUploadRepository.fetch(id: upload.id) ?? uploadingPhotoUploads[upload.id] {
                    try pendingUploadRepository.save(
                        updateUploadItem(
                            latestUpload,
                            state: .failed,
                            lastError: failureReason,
                            lastAttemptAt: latestUpload.lastAttemptAt ?? failedAt,
                            completedAt: nil,
                            incrementAttemptCount: false
                        )
                    )
                }
            }

            throw error
        }
    }

    private func transitionReport(
        _ report: UserReport,
        to status: ReportStatus,
        lastError: String?,
        uploadedAt: Date?,
        incrementAttemptCount: Bool,
        lastUploadAttemptAt: Date? = nil
    ) -> UserReport {
        UserReport(
            id: report.id,
            canonicalPlaceID: report.canonicalPlaceID,
            reportType: report.reportType,
            reportStatus: status,
            userCoordinate: report.userCoordinate,
            suggestedEntranceCoordinate: report.suggestedEntranceCoordinate,
            textNote: report.textNote,
            datasetVersion: report.datasetVersion,
            localCreatedAt: report.localCreatedAt,
            statusUpdatedAt: now(),
            uploadAttemptCount: report.uploadAttemptCount + (incrementAttemptCount ? 1 : 0),
            lastUploadAttemptAt: lastUploadAttemptAt ?? report.lastUploadAttemptAt,
            lastError: lastError,
            uploadedAt: uploadedAt
        )
    }

    private func makeUploadItem(
        id: UUID,
        entityType: PendingUploadEntityType,
        entityID: String,
        reportID: UUID,
        state: PendingUploadState,
        lastError: String?,
        attemptCount: Int,
        lastAttemptAt: Date?,
        completedAt: Date?,
        createdAt: Date,
        updatedAt: Date
    ) -> PendingUploadItem {
        PendingUploadItem(
            id: id,
            entityType: entityType,
            entityID: entityID,
            reportID: reportID,
            uploadState: state,
            lastError: lastError,
            attemptCount: attemptCount,
            lastAttemptAt: lastAttemptAt,
            completedAt: completedAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private func updateUploadItem(
        _ item: PendingUploadItem,
        state: PendingUploadState,
        lastError: String?,
        lastAttemptAt: Date?,
        completedAt: Date?,
        incrementAttemptCount: Bool
    ) -> PendingUploadItem {
        PendingUploadItem(
            id: item.id,
            entityType: item.entityType,
            entityID: item.entityID,
            reportID: item.reportID,
            uploadState: state,
            lastError: lastError,
            attemptCount: item.attemptCount + (incrementAttemptCount ? 1 : 0),
            lastAttemptAt: lastAttemptAt,
            completedAt: completedAt,
            createdAt: item.createdAt,
            updatedAt: now()
        )
    }

    private func upsertReportUploadItem(for report: UserReport, createdAt: Date) throws {
        let existing = try pendingUploadRepository.fetch(entityType: .userReport, entityID: report.id.uuidString)
        let item = existing.map {
            updateUploadItem(
                $0,
                state: .pendingUpload,
                lastError: nil,
                lastAttemptAt: $0.lastAttemptAt,
                completedAt: nil,
                incrementAttemptCount: false
            )
        } ?? makeUploadItem(
            id: UUID(),
            entityType: .userReport,
            entityID: report.id.uuidString,
            reportID: report.id,
            state: .pendingUpload,
            lastError: nil,
            attemptCount: 0,
            lastAttemptAt: nil,
            completedAt: nil,
            createdAt: createdAt,
            updatedAt: now()
        )

        try pendingUploadRepository.save(item)
    }
}
