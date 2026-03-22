import Foundation
import XCTest
@testable import SheltersKit

final class LocalReportingServiceTests: XCTestCase {
    func testCreatePendingReportPersistsPendingLifecycleAndQueueItem() async throws {
        let context = try makeContext()
        let placeID = UUID(uuidString: "22F0B3F7-0D95-4FE7-9D57-543A0300ABCD")!
        try context.placeRepository.upsert([makeCanonicalPlace(id: placeID)])

        let report = try await context.service.createPendingReport(
            from: UserReportDraft(
                canonicalPlaceID: placeID,
                reportType: .wrongLocation,
                userCoordinate: GeoCoordinate(latitude: 32.0853, longitude: 34.7818),
                suggestedEntranceCoordinate: nil,
                textNote: "Entrance marker is offset",
                datasetVersion: "2026.03.12"
            )
        )

        let fetchedReport = try await context.service.fetchReport(id: report.id)
        let storedReport = try XCTUnwrap(fetchedReport)
        let pendingReports = try await context.service.fetchPendingReports()
        let pendingUploads = try await context.service.fetchUploads(for: report.id)

        XCTAssertEqual(storedReport.reportStatus, .pendingUpload)
        XCTAssertEqual(storedReport.canonicalPlaceID, placeID)
        XCTAssertEqual(pendingReports.count, 1)
        XCTAssertEqual(pendingUploads.count, 1)
        XCTAssertEqual(pendingUploads.first?.entityType, .userReport)
        XCTAssertEqual(pendingUploads.first?.uploadState, .pendingUpload)
        XCTAssertEqual(pendingUploads.first?.reportID, report.id)
    }

    func testAttachPreparedPhotoStoresEvidenceAndQueuesPhotoUpload() async throws {
        let context = try makeContext()
        let report = try await context.service.createPendingReport(
            from: UserReportDraft(
                canonicalPlaceID: nil,
                reportType: .photoEvidence,
                userCoordinate: nil,
                suggestedEntranceCoordinate: nil,
                textNote: nil,
                datasetVersion: "2026.03.12"
            )
        )

        let preparedDraft = try await context.service.preparePhotoDraft(
            from: URL(fileURLWithPath: "/tmp/sample.jpg")
        )
        let photo = try await context.service.attachPreparedPhoto(preparedDraft, to: report.id)

        let photos = try await context.service.fetchPhotoEvidence(for: report.id)
        let pendingUploads = try await context.service.fetchUploads(for: report.id)

        XCTAssertEqual(photos.count, 1)
        XCTAssertEqual(photos.first?.id, photo.id)
        XCTAssertEqual(photos.first?.localFilePath, "/tmp/stored-photo.jpg")
        XCTAssertEqual(photos.first?.checksum, "stub-checksum")
        XCTAssertEqual(pendingUploads.count, 2)
        XCTAssertTrue(pendingUploads.contains { $0.entityType == .photoEvidence && $0.entityID == photo.id.uuidString })
    }

    private func makeContext(
        uploadTransport: ReportUploadTransport = UnavailableReportUploadTransport()
    ) throws -> TestContext {
        let database = try SQLiteDatabase.inMemory()
        try DatabaseMigrator().migrate(database)

        let placeRepository = SQLiteCanonicalPlaceRepository(database: database)
        let service = LocalReportingService(
            userReportRepository: SQLiteUserReportRepository(database: database),
            photoEvidenceRepository: SQLitePhotoEvidenceRepository(database: database),
            pendingUploadRepository: SQLitePendingUploadRepository(database: database),
            photoEvidenceDraftPreparer: StubPhotoEvidenceDraftPreparer(),
            uploadTransport: uploadTransport,
            now: { Date(timeIntervalSince1970: 1_741_800_000) }
        )

        return TestContext(service: service, placeRepository: placeRepository)
    }

    private func makeCanonicalPlace(id: UUID) -> CanonicalPlace {
        CanonicalPlace(
            id: id,
            name: LocalizedPlaceText(original: nil, english: "Test Shelter", russian: "Тестовое укрытие", hebrew: "מקלט בדיקה"),
            address: LocalizedPlaceText(original: nil, english: "1 Test Street", russian: "Тестовая улица, 1", hebrew: "רחוב בדיקה 1"),
            city: "Tel Aviv",
            placeType: .publicShelter,
            objectCoordinate: GeoCoordinate(latitude: 32.0853, longitude: 34.7818),
            entranceCoordinate: GeoCoordinate(latitude: 32.0854, longitude: 34.7819),
            preferredRoutingCoordinate: GeoCoordinate(latitude: 32.0854, longitude: 34.7819),
            preferredRoutingPointType: .entrance,
            isPublic: true,
            isAccessible: true,
            status: .active,
            confidenceScore: 0.9,
            routingQuality: 0.8,
            lastVerifiedAt: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

private struct TestContext {
    let service: LocalReportingService
    let placeRepository: SQLiteCanonicalPlaceRepository
}

struct StubPhotoEvidenceDraftPreparer: PhotoEvidenceDraftPreparing {
    func prepareDraft(from fileURL: URL) async throws -> PhotoEvidenceDraft {
        PhotoEvidenceDraft(
            localFilePath: "/tmp/stored-photo.jpg",
            exifCoordinate: GeoCoordinate(latitude: 32.0849, longitude: 34.7821),
            capturedAt: Date(timeIntervalSince1970: 1_731_000_000),
            checksum: "stub-checksum"
        )
    }
}
