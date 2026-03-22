import Foundation

protocol SyncStateStoring: Sendable {
    func load() throws -> SyncStatusSnapshot
    func save(_ snapshot: SyncStatusSnapshot) throws
}

struct RepositoryBackedSyncStateStore: SyncStateStoring {
    private enum Keys {
        static let installedDatasetVersion = "installed_dataset_version"
        static let legacyInstalledDatasetVersion = "dataset_version"
        static let remoteDatasetVersion = "remote_dataset_version"
        static let lastCheckedAt = "last_checked_at"
        static let lastSuccessfulSyncAt = "last_successful_sync_at"
        static let lastPreparedAt = "last_prepared_at"
        static let lastErrorMessage = "last_error_message"
        static let activityState = "sync_activity_state"
        static let updateAvailability = "sync_update_availability"
        static let preparedReplacementPlan = "prepared_replacement_plan"
    }

    private let repository: SyncMetadataRepository

    init(repository: SyncMetadataRepository) {
        self.repository = repository
    }

    func load() throws -> SyncStatusSnapshot {
        let installedDatasetVersion = try nonEmptyValue(for: Keys.installedDatasetVersion)
            ?? nonEmptyValue(for: Keys.legacyInstalledDatasetVersion)

        let remoteDatasetVersion = try nonEmptyValue(for: Keys.remoteDatasetVersion)
        let lastCheckedAt = try nonEmptyValue(for: Keys.lastCheckedAt).flatMap(DateCoding.date)
        let lastSuccessfulSyncAt = try nonEmptyValue(for: Keys.lastSuccessfulSyncAt).flatMap(DateCoding.date)
        let lastPreparedAt = try nonEmptyValue(for: Keys.lastPreparedAt).flatMap(DateCoding.date)
        let lastErrorMessage = try nonEmptyValue(for: Keys.lastErrorMessage)
        let activityState = try nonEmptyValue(for: Keys.activityState).flatMap(SyncActivityState.init(rawValue:)) ?? .idle
        let updateAvailability = try nonEmptyValue(for: Keys.updateAvailability)
            .flatMap(SyncUpdateAvailability.init(rawValue:)) ?? .unknown
        let preparedReplacementPlan = try nonEmptyValue(for: Keys.preparedReplacementPlan)
            .flatMap(decodePreparedPlan(from:))

        return SyncStatusSnapshot(
            installedDatasetVersion: installedDatasetVersion,
            remoteDatasetVersion: remoteDatasetVersion,
            lastCheckedAt: lastCheckedAt,
            lastSuccessfulSyncAt: lastSuccessfulSyncAt,
            lastPreparedAt: lastPreparedAt,
            lastErrorMessage: lastErrorMessage,
            activityState: activityState,
            updateAvailability: updateAvailability,
            preparedReplacementPlan: preparedReplacementPlan
        )
    }

    func save(_ snapshot: SyncStatusSnapshot) throws {
        try repository.setValue(snapshot.installedDatasetVersion ?? "", for: Keys.installedDatasetVersion)
        try repository.setValue(snapshot.remoteDatasetVersion ?? "", for: Keys.remoteDatasetVersion)
        try repository.setValue(snapshot.lastCheckedAt.map(DateCoding.string) ?? "", for: Keys.lastCheckedAt)
        try repository.setValue(snapshot.lastSuccessfulSyncAt.map(DateCoding.string) ?? "", for: Keys.lastSuccessfulSyncAt)
        try repository.setValue(snapshot.lastPreparedAt.map(DateCoding.string) ?? "", for: Keys.lastPreparedAt)
        try repository.setValue(snapshot.lastErrorMessage ?? "", for: Keys.lastErrorMessage)
        try repository.setValue(snapshot.activityState.rawValue, for: Keys.activityState)
        try repository.setValue(snapshot.updateAvailability.rawValue, for: Keys.updateAvailability)
        try repository.setValue(encodePreparedPlan(snapshot.preparedReplacementPlan) ?? "", for: Keys.preparedReplacementPlan)
    }

    private func nonEmptyValue(for key: String) throws -> String? {
        guard let value = try repository.value(for: key), !value.isEmpty else {
            return nil
        }

        return value
    }

    private func encodePreparedPlan(_ plan: AtomicDatabaseReplacementPlan?) -> String? {
        guard let plan else { return nil }

        let data = try? SyncCoding.encoder().encode(plan)
        return data.flatMap { String(data: $0, encoding: .utf8) }
    }

    private func decodePreparedPlan(from string: String) -> AtomicDatabaseReplacementPlan? {
        guard let data = string.data(using: .utf8) else {
            return nil
        }

        return try? SyncCoding.decoder().decode(AtomicDatabaseReplacementPlan.self, from: data)
    }
}

