import Foundation

struct AppContainer {
    let database: SQLiteDatabase
    let placeRepository: SQLiteCanonicalPlaceRepository
    let routingPointRepository: SQLiteRoutingPointRepository
    let sourceAttributionRepository: SQLiteSourceAttributionRepository
    let userReportRepository: SQLiteUserReportRepository
    let photoEvidenceRepository: SQLitePhotoEvidenceRepository
    let pendingUploadRepository: SQLitePendingUploadRepository
    let syncMetadataRepository: SQLiteSyncMetadataRepository
    let appSettingsRepository: SQLiteAppSettingsRepository
    let syncService: SyncService
    let locationService: LocationService
    let nearbySearchService: NearbySearchService
    let routingService: RoutingService
    let reportingService: ReportingService
    let appSettingsService: AppSettingsService
    let settingsStore: SettingsStore
    let environmentConfiguration: AppEnvironmentConfiguration

    @MainActor
    static func bootstrap(
        fileManager: FileManager = .default
    ) throws -> AppContainer {
        let databaseURL = try AppPaths.databaseURL(fileManager: fileManager)
        let database = try SQLiteDatabase(path: databaseURL.path)
        try DatabaseMigrator().migrate(database)
        let environmentConfiguration = AppEnvironmentConfiguration.resolve()

        let placeRepository = SQLiteCanonicalPlaceRepository(database: database)
        let routingPointRepository = SQLiteRoutingPointRepository(database: database)
        let sourceAttributionRepository = SQLiteSourceAttributionRepository(database: database)
        let userReportRepository = SQLiteUserReportRepository(database: database)
        let photoEvidenceRepository = SQLitePhotoEvidenceRepository(database: database)
        let pendingUploadRepository = SQLitePendingUploadRepository(database: database)
        let syncMetadataRepository = SQLiteSyncMetadataRepository(database: database)
        let appSettingsRepository = SQLiteAppSettingsRepository(database: database)

        let syncStateStore = RepositoryBackedSyncStateStore(repository: syncMetadataRepository)
        let remoteMetadataSource: RemoteDatasetMetadataFetching

        if let datasetPublication = environmentConfiguration.datasetPublication {
            remoteMetadataSource = URLSessionRemoteDatasetMetadataSource(endpoint: datasetPublication.metadataURL)
        } else {
            remoteMetadataSource = MissingRemoteDatasetMetadataSource()
        }

        let syncService = DefaultSyncService(
            stateStore: syncStateStore,
            remoteMetadataSource: remoteMetadataSource,
            datasetFileDownloader: URLSessionTemporaryFileDownloader(),
            checksumValidator: SHA256DatasetChecksumValidator(),
            snapshotValidator: SQLiteDatasetSnapshotValidator(),
            localStatePreserver: SQLiteLocalDatabaseStatePreserver(),
            databaseReplacer: SQLiteAtomicDatabaseReplacer(),
            clientVersionProvider: BundleClientVersionProvider(),
            liveDatabase: database,
            liveDatabaseURL: databaseURL
        )
        let locationService = AppleLocationService()
        let nearbySearchService = LocalNearbySearchService(
            placeRepository: placeRepository,
            routingPointRepository: routingPointRepository
        )
        let routingService = URLRoutingService()
        let photoEvidenceStore = AppSupportPhotoEvidenceFileStore(
            destinationDirectoryURL: try AppPaths.reportPhotoDirectoryURL(fileManager: fileManager)
        )
        let photoEvidenceDraftPreparer = DefaultPhotoEvidenceDraftPreparer(
            metadataExtractor: ImageIOPhotoMetadataExtractor(),
            fileStore: photoEvidenceStore
        )
        let uploadTransport: ReportUploadTransport
        if let reportingAPI = environmentConfiguration.reportingAPI {
            uploadTransport = URLSessionReportUploadTransport(configuration: reportingAPI)
        } else {
            uploadTransport = UnavailableReportUploadTransport()
        }

        let reportingService = LocalReportingService(
            userReportRepository: userReportRepository,
            photoEvidenceRepository: photoEvidenceRepository,
            pendingUploadRepository: pendingUploadRepository,
            photoEvidenceDraftPreparer: photoEvidenceDraftPreparer,
            uploadTransport: uploadTransport
        )
        let appSettingsService = DefaultAppSettingsService(repository: appSettingsRepository)
        let settingsStore = SettingsStore(service: appSettingsService)

        return AppContainer(
            database: database,
            placeRepository: placeRepository,
            routingPointRepository: routingPointRepository,
            sourceAttributionRepository: sourceAttributionRepository,
            userReportRepository: userReportRepository,
            photoEvidenceRepository: photoEvidenceRepository,
            pendingUploadRepository: pendingUploadRepository,
            syncMetadataRepository: syncMetadataRepository,
            appSettingsRepository: appSettingsRepository,
            syncService: syncService,
            locationService: locationService,
            nearbySearchService: nearbySearchService,
            routingService: routingService,
            reportingService: reportingService,
            appSettingsService: appSettingsService,
            settingsStore: settingsStore,
            environmentConfiguration: environmentConfiguration
        )
    }
}

enum AppPaths {
    static func databaseURL(fileManager: FileManager) throws -> URL {
        let directory = try baseDirectoryURL(fileManager: fileManager)
        return directory.appendingPathComponent("shelters.sqlite")
    }

    static func reportPhotoDirectoryURL(fileManager: FileManager) throws -> URL {
        try baseDirectoryURL(fileManager: fileManager)
            .appendingPathComponent("ReportPhotos", isDirectory: true)
    }

    private static func baseDirectoryURL(fileManager: FileManager) throws -> URL {
        let appSupportDirectory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = appSupportDirectory.appendingPathComponent("Shelters", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
