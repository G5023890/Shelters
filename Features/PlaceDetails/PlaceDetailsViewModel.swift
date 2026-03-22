import Foundation

@MainActor
final class PlaceDetailsViewModel: ObservableObject {
    @Published private(set) var place: CanonicalPlace?
    @Published private(set) var routingPoints: [RoutingPoint] = []
    @Published private(set) var resolvedRoutingTarget: ResolvedRoutingTarget?
    @Published private(set) var sourceAttributions: [PlaceSourceAttribution] = []
    @Published private(set) var syncStatus = SyncStatusSnapshot.initial
    @Published private(set) var presentation: PlaceDetailsPresentation?
    @Published private(set) var errorMessage: String?

    @Published private(set) var distanceMeters: Double?

    private let placeID: UUID
    private let placeRepository: CanonicalPlaceRepository
    private let routingPointRepository: RoutingPointRepository
    private let sourceAttributionRepository: SourceAttributionRepository
    private let routingTargetSelector: PreferredRoutingPointSelecting
    private let routingService: RoutingService
    private let locationService: LocationService
    private let syncService: SyncService
    private let languageProvider: () -> AppLanguage

    init(
        placeID: UUID,
        initialPlace: CanonicalPlace?,
        distanceMeters: Double?,
        placeRepository: CanonicalPlaceRepository,
        routingPointRepository: RoutingPointRepository,
        sourceAttributionRepository: SourceAttributionRepository,
        routingTargetSelector: PreferredRoutingPointSelecting = PreferredRoutingPointSelector(),
        routingService: RoutingService,
        locationService: LocationService,
        syncService: SyncService,
        languageProvider: @escaping () -> AppLanguage
    ) {
        self.placeID = placeID
        self.place = initialPlace
        self.distanceMeters = distanceMeters
        self.placeRepository = placeRepository
        self.routingPointRepository = routingPointRepository
        self.sourceAttributionRepository = sourceAttributionRepository
        self.routingTargetSelector = routingTargetSelector
        self.routingService = routingService
        self.locationService = locationService
        self.syncService = syncService
        self.languageProvider = languageProvider

        if let initialPlace {
            self.resolvedRoutingTarget = initialPlace.fallbackRoutingTarget
            self.presentation = PlaceDetailsPresentationBuilder.make(
                place: initialPlace,
                language: languageProvider(),
                distanceMeters: distanceMeters,
                syncStatus: nil,
                sourceAttributions: [],
                routingTarget: initialPlace.fallbackRoutingTarget
            )
        }
    }

    var effectiveRoutingTarget: ResolvedRoutingTarget? {
        resolvedRoutingTarget ?? place?.fallbackRoutingTarget
    }

    func routingDestinations(preferredProvider: RoutingAppProvider) -> [RoutingDestination] {
        guard let effectiveRoutingTarget else {
            return []
        }

        return routingService.destinations(
            for: effectiveRoutingTarget,
            preferredProvider: preferredProvider
        )
    }

    func preferredRoutingDestination(preferredProvider: RoutingAppProvider) -> RoutingDestination? {
        guard let effectiveRoutingTarget else {
            return nil
        }

        return routingService.preferredDestination(
            for: effectiveRoutingTarget,
            preferredProvider: preferredProvider
        )
    }

    func load() async {
        do {
            let latestPlace = try placeRepository.fetch(id: placeID)
            async let syncStatusTask = syncService.fetchSyncStatus()
            let routingPoints = try routingPointRepository.fetchRoutingPoints(for: placeID)
            let sourceAttributions = try sourceAttributionRepository.fetchSourceAttributions(for: placeID)

            if let latestPlace {
                place = latestPlace
                self.routingPoints = routingPoints
                self.sourceAttributions = sourceAttributions
                resolvedRoutingTarget = routingTargetSelector.resolve(for: latestPlace, routingPoints: routingPoints)
                syncStatus = await syncStatusTask
                await refreshDistanceIfNeeded(for: latestPlace)
                presentation = PlaceDetailsPresentationBuilder.make(
                    place: latestPlace,
                    language: languageProvider(),
                    distanceMeters: distanceMeters,
                    syncStatus: syncStatus,
                    sourceAttributions: sourceAttributions,
                    routingTarget: resolvedRoutingTarget
                )
                errorMessage = nil
            } else {
                errorMessage = L10n.string(.placeDetailsMissing)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshDistanceIfNeeded(for place: CanonicalPlace) async {
        guard distanceMeters == nil else {
            return
        }

        guard await locationService.authorizationStatus() == .authorized else {
            return
        }

        guard let currentLocation = try? await locationService.currentLocation() else {
            return
        }

        distanceMeters = DistanceCalculator.meters(from: currentLocation.coordinate, to: place.routingCoordinate)
    }
}
