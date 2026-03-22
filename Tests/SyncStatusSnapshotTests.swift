import Foundation
import XCTest
@testable import SheltersKit

final class SyncStatusSnapshotTests: XCTestCase {
    func testUpdatingCanExplicitlyClearRemoteDatasetVersion() {
        let snapshot = SyncStatusSnapshot(
            installedDatasetVersion: "2026.03.01-01",
            remoteDatasetVersion: "2026.03.12-01",
            lastCheckedAt: Date(),
            lastSuccessfulSyncAt: nil,
            lastPreparedAt: nil,
            lastErrorMessage: nil,
            activityState: .updateAvailable,
            updateAvailability: .updateAvailable,
            preparedReplacementPlan: nil
        )

        let updated = snapshot.updating(
            remoteDatasetVersion: .replace(nil),
            activityState: .remoteMetadataUnavailable,
            updateAvailability: .unavailable
        )

        XCTAssertNil(updated.remoteDatasetVersion)
        XCTAssertEqual(updated.installedDatasetVersion, "2026.03.01-01")
        XCTAssertEqual(updated.activityState, .remoteMetadataUnavailable)
        XCTAssertEqual(updated.updateAvailability, .unavailable)
    }
}
