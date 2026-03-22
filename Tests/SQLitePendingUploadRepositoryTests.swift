import Foundation
import XCTest
@testable import SheltersKit

final class SQLitePendingUploadRepositoryTests: XCTestCase {
    func testFetchPendingUploadsExcludesUploadedItems() throws {
        let database = try SQLiteDatabase.inMemory()
        try DatabaseMigrator().migrate(database)

        let repository = SQLitePendingUploadRepository(database: database)
        let now = Date()

        try repository.save(
            PendingUploadItem(
                id: UUID(),
                entityType: .userReport,
                entityID: UUID().uuidString,
                uploadState: .pendingUpload,
                lastError: nil,
                createdAt: now,
                updatedAt: now
            )
        )

        try repository.save(
            PendingUploadItem(
                id: UUID(),
                entityType: .photoEvidence,
                entityID: UUID().uuidString,
                uploadState: .uploaded,
                lastError: nil,
                createdAt: now,
                updatedAt: now
            )
        )

        let pendingUploads = try repository.fetchPendingUploads()

        XCTAssertEqual(pendingUploads.count, 1)
        XCTAssertEqual(pendingUploads.first?.entityType, .userReport)
        XCTAssertEqual(pendingUploads.first?.uploadState, .pendingUpload)
    }
}
