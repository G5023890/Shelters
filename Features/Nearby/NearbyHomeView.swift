import SwiftUI

struct NearbyHomeView: View {
    @ObservedObject private var settingsStore: SettingsStore
    @StateObject private var viewModel: NearbyHomeViewModel
    private let placeRepository: CanonicalPlaceRepository
    private let routingPointRepository: RoutingPointRepository
    private let sourceAttributionRepository: SourceAttributionRepository
    private let locationService: LocationService
    private let syncService: SyncService
    private let reportingService: ReportingService

    init(
        nearbySearchService: NearbySearchService,
        locationService: LocationService,
        syncService: SyncService,
        routingService: RoutingService,
        reportingService: ReportingService,
        placeRepository: CanonicalPlaceRepository,
        routingPointRepository: RoutingPointRepository,
        sourceAttributionRepository: SourceAttributionRepository,
        settingsStore: SettingsStore
    ) {
        self._viewModel = StateObject(
            wrappedValue: NearbyHomeViewModel(
                nearbySearchService: nearbySearchService,
                locationService: locationService,
                syncService: syncService,
                routingService: routingService
            )
        )
        self._settingsStore = ObservedObject(wrappedValue: settingsStore)
        self.placeRepository = placeRepository
        self.routingPointRepository = routingPointRepository
        self.sourceAttributionRepository = sourceAttributionRepository
        self.locationService = locationService
        self.syncService = syncService
        self.reportingService = reportingService
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    SyncStatusCard(syncStatus: viewModel.syncStatus)
                }

                if let message = viewModel.locationMessage, viewModel.candidates.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(message)
                                .foregroundStyle(.secondary)

                            if viewModel.shouldShowLocationRequestButton {
                                Button {
                                    Task {
                                        await viewModel.requestLocationAccess()
                                    }
                                } label: {
                                    Text(L10n.text(.nearbyUseMyLocation))
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                }

                if !viewModel.candidates.isEmpty {
                    Section(L10n.string(.nearbyResultsSection)) {
                        ForEach(viewModel.candidates, id: \.id) { candidate in
                            NavigationLink {
                                PlaceDetailsView(
                                    placeID: candidate.place.id,
                                    initialPlace: candidate.place,
                                    distanceMeters: candidate.distanceMeters,
                                    placeRepository: placeRepository,
                                    routingPointRepository: routingPointRepository,
                                    sourceAttributionRepository: sourceAttributionRepository,
                                    routingService: viewModel.routingService,
                                    reportingService: reportingService,
                                    locationService: locationService,
                                    syncService: syncService,
                                    settingsStore: settingsStore
                                )
                            } label: {
                                NearbyPlaceCard(
                                    place: candidate.place,
                                    routingTarget: candidate.routingTarget,
                                    distanceMeters: candidate.distanceMeters,
                                    walkingMinutes: candidate.estimatedWalkingMinutes,
                                    language: settingsStore.activeLanguage,
                                    rankingScore: candidate.rankingScore
                                )
                                .padding(.vertical, 4)
                            }
                            .listRowSeparator(.hidden)
                        }
                    }
                } else if !viewModel.recentPlaces.isEmpty {
                    Section(L10n.string(.nearbyRecentSection)) {
                        ForEach(viewModel.recentPlaces) { place in
                            NavigationLink {
                                PlaceDetailsView(
                                    placeID: place.id,
                                    initialPlace: place,
                                    distanceMeters: nil,
                                    placeRepository: placeRepository,
                                    routingPointRepository: routingPointRepository,
                                    sourceAttributionRepository: sourceAttributionRepository,
                                    routingService: viewModel.routingService,
                                    reportingService: reportingService,
                                    locationService: locationService,
                                    syncService: syncService,
                                    settingsStore: settingsStore
                                )
                            } label: {
                                NearbyPlaceCard(
                                    place: place,
                                    routingTarget: place.fallbackRoutingTarget,
                                    distanceMeters: nil,
                                    walkingMinutes: nil,
                                    language: settingsStore.activeLanguage,
                                    rankingScore: nil
                                )
                                .padding(.vertical, 4)
                            }
                            .listRowSeparator(.hidden)
                        }
                    }
                } else {
                    Section {
                        ContentUnavailableView(
                            L10n.string(.nearbyEmptyTitle),
                            systemImage: "building.2.crop.circle",
                            description: Text(L10n.text(.nearbyEmptyMessage))
                        )
                    }
                }
            }
            .listStyle(.inset)
            .navigationTitle(L10n.string(.nearbyTitle))
            .toolbar {
                ToolbarItem {
                    Button {
                        Task {
                            await viewModel.load()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel(L10n.string(.nearbyRefresh))
                }
            }
            .refreshable {
                await viewModel.load()
            }
        }
        .task {
            await viewModel.load()
        }
    }
}

@MainActor
private final class NearbyHomeViewModel: ObservableObject {
    @Published private(set) var candidates: [NearbyPlaceCandidate] = []
    @Published private(set) var recentPlaces: [CanonicalPlace] = []
    @Published private(set) var syncStatus = SyncStatusSnapshot.initial
    @Published private(set) var locationMessage: String?
    @Published private(set) var authorizationStatus: LocationAuthorizationStatus = .notDetermined

    let routingService: RoutingService

    private let nearbySearchService: NearbySearchService
    private let locationService: LocationService
    private let syncService: SyncService

    init(
        nearbySearchService: NearbySearchService,
        locationService: LocationService,
        syncService: SyncService,
        routingService: RoutingService
    ) {
        self.nearbySearchService = nearbySearchService
        self.locationService = locationService
        self.syncService = syncService
        self.routingService = routingService
    }

    var shouldShowLocationRequestButton: Bool {
        authorizationStatus == .notDetermined
    }

    func load() async {
        syncStatus = await syncService.fetchSyncStatus()
        authorizationStatus = await locationService.authorizationStatus()

        do {
            switch authorizationStatus {
            case .authorized:
                if let location = try await locationService.currentLocation() {
                    candidates = try await nearbySearchService.searchNearby(
                        from: location.coordinate,
                        radiusMeters: 5_000,
                        limit: 20
                    )
                    recentPlaces = []
                    locationMessage = candidates.isEmpty
                        ? L10n.formatted(.nearbyEmergencyCutoffMessage, ShelterAccessPolicy.maxEmergencyWalkingMinutes)
                        : nil
                } else {
                    recentPlaces = try await nearbySearchService.recentPlaces(limit: 20)
                    candidates = []
                    locationMessage = L10n.string(.nearbyLocationUnavailable)
                }
            case .notDetermined, .denied, .restricted:
                recentPlaces = try await nearbySearchService.recentPlaces(limit: 20)
                candidates = []
                locationMessage = makeLocationMessage(for: authorizationStatus)
            }
        } catch {
            candidates = []
            recentPlaces = (try? await nearbySearchService.recentPlaces(limit: 20)) ?? []
            locationMessage = error.localizedDescription
        }
    }

    func requestLocationAccess() async {
        authorizationStatus = await locationService.requestPermission()
        await load()
    }

    private func makeLocationMessage(for status: LocationAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return L10n.string(.nearbyLocationPermissionPrompt)
        case .denied, .restricted:
            return L10n.string(.nearbyLocationDenied)
        case .authorized:
            return L10n.string(.nearbyLocationUnavailable)
        }
    }
}
