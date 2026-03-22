import Foundation

actor DefaultSyncService: SyncService {
    private let stateStore: SyncStateStoring
    private let remoteMetadataSource: RemoteDatasetMetadataFetching
    private let datasetFileDownloader: DatasetFileDownloading
    private let checksumValidator: DatasetChecksumValidating
    private let snapshotValidator: DatasetSnapshotValidating
    private let localStatePreserver: LocalDatabaseStatePreserving
    private let databaseReplacer: AtomicDatabaseReplacing
    private let clientVersionProvider: ClientVersionProviding
    private let liveDatabase: SQLiteDatabase
    private let liveDatabaseURL: URL
    private let supportedSchemaVersion: Int
    private let fileManager: FileManager

    init(
        stateStore: SyncStateStoring,
        remoteMetadataSource: RemoteDatasetMetadataFetching,
        datasetFileDownloader: DatasetFileDownloading,
        checksumValidator: DatasetChecksumValidating,
        snapshotValidator: DatasetSnapshotValidating,
        localStatePreserver: LocalDatabaseStatePreserving,
        databaseReplacer: AtomicDatabaseReplacing,
        clientVersionProvider: ClientVersionProviding,
        liveDatabase: SQLiteDatabase,
        liveDatabaseURL: URL,
        supportedSchemaVersion: Int = DatabaseSchemaMigrations.latestVersion,
        fileManager: FileManager = .default
    ) {
        self.stateStore = stateStore
        self.remoteMetadataSource = remoteMetadataSource
        self.datasetFileDownloader = datasetFileDownloader
        self.checksumValidator = checksumValidator
        self.snapshotValidator = snapshotValidator
        self.localStatePreserver = localStatePreserver
        self.databaseReplacer = databaseReplacer
        self.clientVersionProvider = clientVersionProvider
        self.liveDatabase = liveDatabase
        self.liveDatabaseURL = liveDatabaseURL
        self.supportedSchemaVersion = supportedSchemaVersion
        self.fileManager = fileManager
    }

    func fetchSyncStatus() async -> SyncStatusSnapshot {
        (try? stateStore.load()) ?? .initial
    }

    func synchronizeNow() async -> SyncOperationResult {
        var snapshot = await fetchSyncStatus().updating(
            lastCheckedAt: .replace(Date()),
            lastErrorMessage: .replace(nil),
            activityState: .checkingRemoteMetadata,
            updateAvailability: .unknown
        )
        persist(snapshot)

        let currentClientVersion = clientVersionProvider.currentVersion()
        var remoteVersionInfo: DatasetVersionInfo?
        var downloadedDataset: DownloadedDatasetFile?

        do {
            let response = try await remoteMetadataSource.fetchLatestVersionResponse()
            remoteVersionInfo = response.makeDomainModel()
            guard let remoteVersionInfo else {
                throw SyncExecutionError.metadataDecodingFailed
            }

            try validateRemoteMetadata(remoteVersionInfo, currentClientVersion: currentClientVersion)

            let availability = updateAvailability(
                installedVersion: snapshot.installedDatasetVersion,
                remoteVersion: remoteVersionInfo.datasetVersion
            )

            snapshot = snapshot.updating(
                remoteDatasetVersion: .replace(remoteVersionInfo.datasetVersion),
                lastCheckedAt: .replace(Date()),
                lastSuccessfulSyncAt: availability == .upToDate ? .replace(Date()) : .keep,
                lastErrorMessage: .replace(nil),
                activityState: availability == .upToDate ? .upToDate : .updateAvailable,
                updateAvailability: availability,
                preparedReplacementPlan: availability == .upToDate ? .replace(nil) : .keep
            )
            persist(snapshot)

            guard availability == .updateAvailable else {
                return SyncOperationResult(
                    snapshot: snapshot,
                    remoteVersionInfo: remoteVersionInfo,
                    didInstallUpdate: false
                )
            }

            snapshot = snapshot.updating(
                lastErrorMessage: .replace(nil),
                activityState: .downloadingDataset
            )
            persist(snapshot)

            downloadedDataset = try await datasetFileDownloader.download(from: remoteVersionInfo.downloadURL)

            snapshot = snapshot.updating(
                lastErrorMessage: .replace(nil),
                activityState: .validatingChecksum
            )
            persist(snapshot)

            if let downloadedDataset {
                _ = try await checksumValidator.validate(
                    fileAt: downloadedDataset.fileURL,
                    expectedChecksum: remoteVersionInfo.checksum
                )

                try snapshotValidator.validateSnapshot(
                    at: downloadedDataset.fileURL,
                    metadata: remoteVersionInfo,
                    supportedSchemaVersion: supportedSchemaVersion,
                    currentClientVersion: currentClientVersion
                )

                let replacementPlan = try databaseReplacer.stageReplacementCandidate(
                    downloadedFileURL: downloadedDataset.fileURL,
                    liveDatabaseURL: liveDatabaseURL,
                    datasetVersion: remoteVersionInfo.datasetVersion
                )

                try localStatePreserver.mergeLocalState(
                    from: liveDatabaseURL,
                    into: replacementPlan.stagedDatabaseURL
                )

                snapshot = snapshot.updating(
                    lastPreparedAt: .replace(Date()),
                    activityState: .readyToReplaceDatabase,
                    preparedReplacementPlan: .replace(replacementPlan)
                )
                persist(snapshot)

                try liveDatabase.replaceOnDisk(using: replacementPlan, replacer: databaseReplacer)
            }

            snapshot = snapshot.updating(
                installedDatasetVersion: .replace(remoteVersionInfo.datasetVersion),
                remoteDatasetVersion: .replace(remoteVersionInfo.datasetVersion),
                lastCheckedAt: .replace(Date()),
                lastSuccessfulSyncAt: .replace(Date()),
                lastPreparedAt: .replace(Date()),
                lastErrorMessage: .replace(nil),
                activityState: .upToDate,
                updateAvailability: .upToDate,
                preparedReplacementPlan: .replace(nil)
            )
            try persistOrThrow(snapshot)

            if let downloadedDataset {
                try? fileManager.removeItem(at: downloadedDataset.fileURL)
            }

            return SyncOperationResult(
                snapshot: snapshot,
                remoteVersionInfo: remoteVersionInfo,
                didInstallUpdate: true
            )
        } catch {
            snapshot = snapshot.updating(
                lastCheckedAt: .replace(Date()),
                lastErrorMessage: .replace(error.localizedDescription),
                activityState: .failed,
                updateAvailability: updateAvailability(
                    installedVersion: snapshot.installedDatasetVersion,
                    remoteVersion: remoteVersionInfo?.datasetVersion
                )
            )
            persist(snapshot)

            if let downloadedDataset {
                try? fileManager.removeItem(at: downloadedDataset.fileURL)
            }

            return SyncOperationResult(
                snapshot: snapshot,
                remoteVersionInfo: remoteVersionInfo,
                didInstallUpdate: false
            )
        }
    }

    private func validateRemoteMetadata(
        _ metadata: DatasetVersionInfo,
        currentClientVersion: String
    ) throws {
        guard metadata.schemaVersion == supportedSchemaVersion else {
            throw SyncExecutionError.unsupportedSchemaVersion(
                expected: supportedSchemaVersion,
                received: metadata.schemaVersion
            )
        }

        if let minimumClientVersion = metadata.minimumClientVersion,
           !ClientVersionComparator.isSupported(
                current: currentClientVersion,
                minimumRequired: minimumClientVersion
           ) {
            throw SyncExecutionError.unsupportedMinimumClientVersion(
                required: minimumClientVersion,
                current: currentClientVersion
            )
        }
    }

    private func updateAvailability(installedVersion: String?, remoteVersion: String?) -> SyncUpdateAvailability {
        guard let remoteVersion else {
            return .unknown
        }

        return remoteVersion == installedVersion ? .upToDate : .updateAvailable
    }

    private func persist(_ snapshot: SyncStatusSnapshot) {
        try? stateStore.save(snapshot)
    }

    private func persistOrThrow(_ snapshot: SyncStatusSnapshot) throws {
        do {
            try stateStore.save(snapshot)
        } catch {
            throw SyncExecutionError.syncMetadataPersistenceFailed
        }
    }
}
