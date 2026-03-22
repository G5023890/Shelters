import Foundation
import XCTest
@testable import SheltersKit

final class SQLiteReportingRepositoriesTests: XCTestCase {
    func testPendingReportsExcludeUploadedReports() throws {
        let database = try SQLiteDatabase.inMemory()
        try DatabaseMigrator().migrate(database)

        let repository = SQLiteUserReportRepository(database: database)
        let reportID = UUID()

        try repository.save(
            UserReport(
                id: reportID,
                canonicalPlaceID: nil,
                reportType: .wrongLocation,
                reportStatus: .pendingUpload,
                userCoordinate: nil,
                suggestedEntranceCoordinate: nil,
                textNote: "Pending",
                datasetVersion: "2026.03.12",
                localCreatedAt: Date(),
                uploadedAt: nil
            )
        )
        try repository.save(
            UserReport(
                id: UUID(),
                canonicalPlaceID: nil,
                reportType: .confirmLocation,
                reportStatus: .uploaded,
                userCoordinate: nil,
                suggestedEntranceCoordinate: nil,
                textNote: "Uploaded",
                datasetVersion: "2026.03.12",
                localCreatedAt: Date(),
                uploadedAt: Date()
            )
        )

        let pending = try repository.fetchPendingReports()

        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending.first?.id, reportID)
    }

    func testFetchAllReturnsFailedAndUploadedHistoryInNewestFirstOrder() throws {
        let database = try SQLiteDatabase.inMemory()
        try DatabaseMigrator().migrate(database)

        let repository = SQLiteUserReportRepository(database: database)
        let older = UserReport(
            id: UUID(),
            canonicalPlaceID: nil,
            reportType: .wrongLocation,
            reportStatus: .failed,
            userCoordinate: nil,
            suggestedEntranceCoordinate: nil,
            textNote: "Older",
            datasetVersion: "2026.03.12",
            localCreatedAt: Date(timeIntervalSince1970: 100),
            uploadedAt: nil
        )
        let newer = UserReport(
            id: UUID(),
            canonicalPlaceID: nil,
            reportType: .confirmLocation,
            reportStatus: .uploaded,
            userCoordinate: nil,
            suggestedEntranceCoordinate: nil,
            textNote: "Newer",
            datasetVersion: "2026.03.12",
            localCreatedAt: Date(timeIntervalSince1970: 200),
            uploadedAt: Date(timeIntervalSince1970: 300)
        )

        try repository.save(older)
        try repository.save(newer)

        let reports = try repository.fetchAll(limit: nil)

        XCTAssertEqual(reports.map(\.id), [newer.id, older.id])
    }

    func testPhotoEvidenceFetchReturnsOnlyRowsForRequestedReport() throws {
        let database = try SQLiteDatabase.inMemory()
        try DatabaseMigrator().migrate(database)

        let reportRepository = SQLiteUserReportRepository(database: database)
        let repository = SQLitePhotoEvidenceRepository(database: database)
        let reportID = UUID()
        let otherReportID = UUID()

        try reportRepository.save(
            UserReport(
                id: reportID,
                canonicalPlaceID: nil,
                reportType: .photoEvidence,
                reportStatus: .pendingUpload,
                userCoordinate: nil,
                suggestedEntranceCoordinate: nil,
                textNote: nil,
                datasetVersion: "2026.03.12",
                localCreatedAt: Date(),
                uploadedAt: nil
            )
        )
        try reportRepository.save(
            UserReport(
                id: otherReportID,
                canonicalPlaceID: nil,
                reportType: .photoEvidence,
                reportStatus: .pendingUpload,
                userCoordinate: nil,
                suggestedEntranceCoordinate: nil,
                textNote: nil,
                datasetVersion: "2026.03.12",
                localCreatedAt: Date(),
                uploadedAt: nil
            )
        )

        try repository.save(
            PhotoEvidence(
                id: UUID(),
                reportID: reportID,
                localFilePath: "/tmp/report-a.jpg",
                exifCoordinate: GeoCoordinate(latitude: 32.1, longitude: 34.8),
                capturedAt: Date(timeIntervalSince1970: 100),
                hasMetadata: true,
                checksum: "a"
            )
        )
        try repository.save(
            PhotoEvidence(
                id: UUID(),
                reportID: otherReportID,
                localFilePath: "/tmp/report-b.jpg",
                exifCoordinate: nil,
                capturedAt: Date(timeIntervalSince1970: 200),
                hasMetadata: false,
                checksum: nil
            )
        )

        let photos = try repository.fetchPhotoEvidence(for: reportID)

        XCTAssertEqual(photos.count, 1)
        XCTAssertEqual(photos.first?.localFilePath, "/tmp/report-a.jpg")
    }
}
