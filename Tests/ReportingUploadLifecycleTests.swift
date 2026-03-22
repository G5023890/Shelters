import Foundation
import XCTest
@testable import SheltersKit

final class ReportingUploadLifecycleTests: XCTestCase {
    func testProcessPendingUploadsMarksReportAndPhotoUploadedOnSuccess() async throws {
        let transport = CapturingReportUploadTransport()
        let context = try makeContext(uploadTransport: transport)
        let report = try await context.service.createPendingReport(from: makeDraft())
        let photoDraft = try await context.service.preparePhotoDraft(from: URL(fileURLWithPath: "/tmp/report.jpg"))
        _ = try await context.service.attachPreparedPhoto(photoDraft, to: report.id)

        let result = try await context.service.processPendingUploads()
        let fetchedReport = try await context.service.fetchReport(id: report.id)
        let storedReport = try XCTUnwrap(fetchedReport)
        let uploads = try await context.service.fetchUploads(for: report.id)

        XCTAssertEqual(result.succeededReportIDs, [report.id])
        XCTAssertEqual(storedReport.reportStatus, .uploaded)
        XCTAssertEqual(storedReport.uploadAttemptCount, 1)
        XCTAssertNotNil(storedReport.uploadedAt)
        XCTAssertTrue(uploads.allSatisfy { $0.uploadState == .uploaded })
        XCTAssertEqual(transport.uploadedReports.count, 1)
        XCTAssertEqual(transport.uploadedPhotos.count, 1)
    }

    func testProcessPendingUploadsMarksFailureAndRetryCanSucceed() async throws {
        let transport = FlakyReportUploadTransport()
        let context = try makeContext(uploadTransport: transport)
        let report = try await context.service.createPendingReport(from: makeDraft())

        let firstResult = try await context.service.processPendingUploads()
        let fetchedFailedReport = try await context.service.fetchReport(id: report.id)
        let failedReport = try XCTUnwrap(fetchedFailedReport)
        let failedUploads = try await context.service.fetchUploads(for: report.id)

        XCTAssertEqual(firstResult.failedReportIDs, [report.id])
        XCTAssertEqual(failedReport.reportStatus, .failed)
        XCTAssertEqual(failedReport.uploadAttemptCount, 1)
        XCTAssertNotNil(failedReport.lastError)
        XCTAssertTrue(failedUploads.allSatisfy { $0.uploadState == .failed })

        let retryResult = try await context.service.retryUpload(for: report.id)
        let fetchedRetriedReport = try await context.service.fetchReport(id: report.id)
        let retriedReport = try XCTUnwrap(fetchedRetriedReport)
        let retriedUploads = try await context.service.fetchUploads(for: report.id)

        XCTAssertEqual(retryResult.succeededReportIDs, [report.id])
        XCTAssertEqual(retriedReport.reportStatus, .uploaded)
        XCTAssertEqual(retriedReport.uploadAttemptCount, 2)
        XCTAssertNil(retriedReport.lastError)
        XCTAssertTrue(retriedUploads.allSatisfy { $0.uploadState == .uploaded })
    }

    private func makeContext(uploadTransport: ReportUploadTransport) throws -> ReportingLifecycleContext {
        let database = try SQLiteDatabase.inMemory()
        try DatabaseMigrator().migrate(database)

        let service = LocalReportingService(
            userReportRepository: SQLiteUserReportRepository(database: database),
            photoEvidenceRepository: SQLitePhotoEvidenceRepository(database: database),
            pendingUploadRepository: SQLitePendingUploadRepository(database: database),
            photoEvidenceDraftPreparer: StubPhotoEvidenceDraftPreparer(),
            uploadTransport: uploadTransport,
            now: { Date(timeIntervalSince1970: 1_741_800_000) }
        )

        return ReportingLifecycleContext(service: service)
    }

    private func makeDraft() -> UserReportDraft {
        UserReportDraft(
            canonicalPlaceID: nil,
            reportType: .wrongLocation,
            userCoordinate: GeoCoordinate(latitude: 32.0853, longitude: 34.7818),
            suggestedEntranceCoordinate: GeoCoordinate(latitude: 32.0854, longitude: 34.7819),
            textNote: "Offset marker",
            datasetVersion: "2026.03.12"
        )
    }
}

private struct ReportingLifecycleContext {
    let service: LocalReportingService
}

private final class CapturingReportUploadTransport: ReportUploadTransport, @unchecked Sendable {
    private(set) var uploadedReports: [UUID] = []
    private(set) var uploadedPhotos: [UUID] = []

    func uploadReport(_ payload: ReportUploadPayload) async throws -> UploadedReportReceipt {
        uploadedReports.append(payload.localReportID)
        return UploadedReportReceipt(remoteReportID: "remote-\(payload.localReportID.uuidString)")
    }

    func uploadPhotoEvidence(
        _ payload: PhotoEvidenceUploadPayload,
        reportReceipt: UploadedReportReceipt
    ) async throws {
        uploadedPhotos.append(payload.localPhotoID)
    }
}

private final class FlakyReportUploadTransport: ReportUploadTransport, @unchecked Sendable {
    private var didFailFirstUpload = false

    func uploadReport(_ payload: ReportUploadPayload) async throws -> UploadedReportReceipt {
        if !didFailFirstUpload {
            didFailFirstUpload = true
            throw StubTransportError.unavailable
        }

        return UploadedReportReceipt(remoteReportID: "remote-\(payload.localReportID.uuidString)")
    }

    func uploadPhotoEvidence(
        _ payload: PhotoEvidenceUploadPayload,
        reportReceipt: UploadedReportReceipt
    ) async throws {}
}

private enum StubTransportError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        "Transport temporarily unavailable"
    }
}
