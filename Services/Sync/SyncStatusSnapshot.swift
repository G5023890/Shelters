import Foundation

enum SnapshotValueUpdate<Value> {
    case keep
    case replace(Value)
}

enum SyncActivityState: String, Hashable, Codable, Sendable {
    case idle
    case checkingRemoteMetadata = "checking_remote_metadata"
    case remoteMetadataUnavailable = "remote_metadata_unavailable"
    case updateAvailable = "update_available"
    case upToDate = "up_to_date"
    case downloadingDataset = "downloading_dataset"
    case validatingChecksum = "validating_checksum"
    case readyToReplaceDatabase = "ready_to_replace_database"
    case failed

    var localizationKey: L10n.Key {
        switch self {
        case .idle:
            return .syncActivityIdle
        case .checkingRemoteMetadata:
            return .syncActivityCheckingRemoteMetadata
        case .remoteMetadataUnavailable:
            return .syncActivityRemoteMetadataUnavailable
        case .updateAvailable:
            return .syncActivityUpdateAvailable
        case .upToDate:
            return .syncActivityUpToDate
        case .downloadingDataset:
            return .syncActivityDownloadingDataset
        case .validatingChecksum:
            return .syncActivityValidatingChecksum
        case .readyToReplaceDatabase:
            return .syncActivityReadyToReplaceDatabase
        case .failed:
            return .syncActivityFailed
        }
    }
}

enum SyncUpdateAvailability: String, Hashable, Codable, Sendable {
    case unknown
    case unavailable
    case upToDate = "up_to_date"
    case updateAvailable = "update_available"

    var localizationKey: L10n.Key {
        switch self {
        case .unknown:
            return .syncAvailabilityUnknown
        case .unavailable:
            return .syncAvailabilityUnavailable
        case .upToDate:
            return .syncAvailabilityUpToDate
        case .updateAvailable:
            return .syncAvailabilityUpdateAvailable
        }
    }
}

struct SyncStatusSnapshot: Hashable, Sendable {
    let installedDatasetVersion: String?
    let remoteDatasetVersion: String?
    let lastCheckedAt: Date?
    let lastSuccessfulSyncAt: Date?
    let lastPreparedAt: Date?
    let lastErrorMessage: String?
    let activityState: SyncActivityState
    let updateAvailability: SyncUpdateAvailability
    let preparedReplacementPlan: AtomicDatabaseReplacementPlan?

    var datasetVersion: String? {
        installedDatasetVersion
    }

    static let initial = SyncStatusSnapshot(
        installedDatasetVersion: nil,
        remoteDatasetVersion: nil,
        lastCheckedAt: nil,
        lastSuccessfulSyncAt: nil,
        lastPreparedAt: nil,
        lastErrorMessage: nil,
        activityState: .idle,
        updateAvailability: .unknown,
        preparedReplacementPlan: nil
    )

    func updating(
        installedDatasetVersion: SnapshotValueUpdate<String?> = .keep,
        remoteDatasetVersion: SnapshotValueUpdate<String?> = .keep,
        lastCheckedAt: SnapshotValueUpdate<Date?> = .keep,
        lastSuccessfulSyncAt: SnapshotValueUpdate<Date?> = .keep,
        lastPreparedAt: SnapshotValueUpdate<Date?> = .keep,
        lastErrorMessage: SnapshotValueUpdate<String?> = .keep,
        activityState: SyncActivityState? = nil,
        updateAvailability: SyncUpdateAvailability? = nil,
        preparedReplacementPlan: SnapshotValueUpdate<AtomicDatabaseReplacementPlan?> = .keep
    ) -> SyncStatusSnapshot {
        SyncStatusSnapshot(
            installedDatasetVersion: resolve(installedDatasetVersion, current: self.installedDatasetVersion),
            remoteDatasetVersion: resolve(remoteDatasetVersion, current: self.remoteDatasetVersion),
            lastCheckedAt: resolve(lastCheckedAt, current: self.lastCheckedAt),
            lastSuccessfulSyncAt: resolve(lastSuccessfulSyncAt, current: self.lastSuccessfulSyncAt),
            lastPreparedAt: resolve(lastPreparedAt, current: self.lastPreparedAt),
            lastErrorMessage: resolve(lastErrorMessage, current: self.lastErrorMessage),
            activityState: activityState ?? self.activityState,
            updateAvailability: updateAvailability ?? self.updateAvailability,
            preparedReplacementPlan: resolve(preparedReplacementPlan, current: self.preparedReplacementPlan)
        )
    }

    private func resolve<Value>(_ update: SnapshotValueUpdate<Value>, current: Value) -> Value {
        switch update {
        case .keep:
            return current
        case .replace(let value):
            return value
        }
    }
}
