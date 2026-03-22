import MapKit
import SwiftUI
#if os(macOS)
import AppKit
#endif

struct MapPreviewView: View {
    @ObservedObject private var settingsStore: SettingsStore
    @StateObject private var viewModel: MapPreviewViewModel
    @State private var searchText = ""
    @State private var isPickingLocation = false

    init(
        placeRepository: CanonicalPlaceRepository,
        routingPointRepository: RoutingPointRepository,
        locationService: LocationService,
        settingsStore: SettingsStore
    ) {
        self._settingsStore = ObservedObject(wrappedValue: settingsStore)
        self._searchText = State(initialValue: Self.defaultSearchText)
        self._viewModel = StateObject(
            wrappedValue: MapPreviewViewModel(
                placeRepository: placeRepository,
                routingPointRepository: routingPointRepository,
                locationService: locationService,
                initialPreferredCity: Self.defaultPreferredCity,
                languageProvider: { settingsStore.activeLanguage }
            )
        )
    }

    private static var defaultSearchText: String {
#if os(macOS)
        ShelterAccessPolicy.defaultPreviewCity
#else
        ""
#endif
    }

    private static var defaultPreferredCity: String? {
#if os(macOS)
        ShelterAccessPolicy.defaultPreviewCity
#else
        nil
#endif
    }

    private var displayedPlaces: [CanonicalPlace] {
        viewModel.filteredPlaces(
            matching: searchText,
            language: settingsStore.activeLanguage
        )
    }

    private var mapDisplayedPlaces: [CanonicalPlace] {
        viewModel.mapPlaces(
            matching: searchText,
            language: settingsStore.activeLanguage
        )
    }

    var body: some View {
#if os(iOS)
        NavigationStack {
            mapDetailScene
                .navigationTitle(L10n.text(.mapPreviewTitle))
        }
        .task {
            await viewModel.loadIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .sheltersDatasetDidSync)) { _ in
            Task {
                await viewModel.handleDatasetDidSync()
            }
        }
        .onChange(of: viewModel.travelMode) { _, _ in
            Task {
                await viewModel.refreshForTravelModeChange()
            }
        }
#else
        NavigationSplitView {
            List {
                Section {
                    if let locationMessage = viewModel.locationMessage {
                        Text(locationMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
                        Button {
                            Task {
                                await viewModel.refreshData()
                            }
                        } label: {
                            Label(L10n.text(.mapPreviewRefresh), systemImage: "arrow.clockwise")
                        }

                        Button {
                            isPickingLocation = false
                            Task {
                                await viewModel.requestOrRefreshLocation()
                            }
                        } label: {
                            Label(L10n.text(.mapPreviewUseMyLocation), systemImage: "location")
                        }

                        Button {
                            isPickingLocation.toggle()
                        } label: {
                            Label(
                                L10n.string(
                                    isPickingLocation
                                        ? .mapPreviewCancelPickLocation
                                        : .mapPreviewPickLocation,
                                    language: settingsStore.activeLanguage
                                ),
                                systemImage: isPickingLocation ? "xmark" : "mappin.and.ellipse"
                            )
                        }

                        if viewModel.isUsingManualLocation {
                            Button {
                                isPickingLocation = false
                                Task {
                                    await viewModel.clearManualLocation()
                                }
                            } label: {
                                Label(L10n.text(.mapPreviewClearPickedLocation), systemImage: "location.slash")
                            }
                        }
                    }
                    .buttonStyle(.bordered)

                    Picker(L10n.text(.mapPreviewRouteMode), selection: $viewModel.travelMode) {
                        ForEach(MapPreviewTravelMode.allCases) { mode in
                            Text(L10n.string(mode.localizationKey, language: settingsStore.activeLanguage))
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

#if os(macOS)
                    Text(
                        L10n.formatted(
                            .mapPreviewPolicyNote,
                            language: settingsStore.activeLanguage,
                            ShelterAccessPolicy.defaultPreviewCity,
                            ShelterAccessPolicy.maxEmergencyWalkingMinutes
                        )
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
#endif
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                if !viewModel.routeCandidates.isEmpty {
                    Section(L10n.string(.mapPreviewNearestRoutesSection, language: settingsStore.activeLanguage)) {
                        ForEach(Array(viewModel.routeCandidates.enumerated()), id: \.element.id) { index, candidate in
                            Button {
                                Task {
                                    await viewModel.startNavigation(candidateID: candidate.id)
                                }
                            } label: {
                                MapPreviewNearestRouteRow(
                                    rank: index + 1,
                                    candidate: candidate,
                                    isSelected: candidate.id == viewModel.activeRouteCandidateID,
                                    isActive: candidate.id == viewModel.activeRouteCandidateID && viewModel.isNavigationActive,
                                    language: settingsStore.activeLanguage
                                )
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(
                                candidate.id == viewModel.activeRouteCandidateID
                                    ? viewModel.routeColor(forRank: index, candidateID: candidate.id).opacity(0.14)
                                    : Color.clear
                            )
                        }
                    }
                }

                Section(L10n.string(.mapPreviewPlacesSection, language: settingsStore.activeLanguage)) {
                    if displayedPlaces.isEmpty, !viewModel.isLoading {
                        ContentUnavailableView(
                            L10n.string(.mapPreviewEmptyTitle, language: settingsStore.activeLanguage),
                            systemImage: "map",
                            description: Text(L10n.text(.mapPreviewEmptyMessage))
                        )
                    } else {
                        ForEach(displayedPlaces) { place in
                            Button {
                                Task {
                                    await viewModel.selectPlace(id: place.id)
                                }
                            } label: {
                                MapPreviewPlaceRow(
                                    place: place,
                                    isSelected: place.id == viewModel.selectedPlace?.id,
                                    distanceMeters: viewModel.distanceToPlace(place),
                                    language: settingsStore.activeLanguage
                                )
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(
                                place.id == viewModel.selectedPlace?.id
                                    ? Color.accentColor.opacity(0.14)
                                    : Color.clear
                            )
                        }
                    }
                }

                if let selectedPlace = viewModel.selectedPlace, !viewModel.routeTargetOptions.isEmpty {
                    Section(L10n.string(.mapPreviewRoutingPointsSection, language: settingsStore.activeLanguage)) {
                        ForEach(viewModel.routeTargetOptions) { option in
                            Button {
                                Task {
                                    await viewModel.selectRouteTarget(id: option.id)
                                }
                            } label: {
                                MapPreviewRouteTargetRow(
                                    option: option,
                                    isSelected: option.id == viewModel.selectedRouteTarget?.id,
                                    selectedPlace: selectedPlace,
                                    language: settingsStore.activeLanguage
                                )
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(
                                option.id == viewModel.selectedRouteTarget?.id
                                    ? Color.orange.opacity(0.14)
                                    : Color.clear
                            )
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 300, ideal: 360)
            .navigationTitle(L10n.text(.mapPreviewTitle))
            .searchable(
                text: $searchText,
                prompt: Text(L10n.text(.mapPreviewSearchPrompt))
            )
        } detail: {
            mapDetailScene
            .navigationTitle(L10n.text(.mapPreviewTitle))
        }
        .task {
            await viewModel.loadIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .sheltersDatasetDidSync)) { _ in
            Task {
                await viewModel.handleDatasetDidSync()
            }
        }
        .onChange(of: viewModel.travelMode) { _, _ in
            Task {
                await viewModel.refreshForTravelModeChange()
            }
        }
#endif
    }

    @ViewBuilder
    private var mapDetailScene: some View {
#if os(macOS)
        MacPhonePreviewShell {
            mapDetailContent
        }
#else
        mapDetailContent
#endif
    }

    private var mapDetailContent: some View {
        ZStack(alignment: .bottom) {
            if viewModel.places.isEmpty, !viewModel.isLoading {
                ContentUnavailableView(
                    L10n.string(.mapPreviewEmptyTitle, language: settingsStore.activeLanguage),
                    systemImage: "map",
                    description: Text(L10n.text(.mapPreviewEmptyMessage))
                )
            } else {
                MapReader { proxy in
                    Map(position: $viewModel.cameraPosition) {
                        mapContent
                    }
                    .mapStyle(.standard(elevation: .realistic, emphasis: .muted))
                    .mapControls {
                        MapCompass()
                        MapScaleView()
                        MapPitchToggle()
                    }
                    .onMapCameraChange(frequency: .continuous) { context in
                        viewModel.updateVisibleRegion(context.region)
                    }
                    .overlay(alignment: .topTrailing) {
                        if viewModel.isLoadingRoute {
                            ProgressView()
                                .padding(12)
                                .background(.regularMaterial, in: Capsule())
                                .padding()
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Label(
                                    L10n.string(.mapPreviewTitle, language: settingsStore.activeLanguage),
                                    systemImage: "iphone"
                                )

                                if let selectedPlace = viewModel.selectedPlace {
                                    Text(selectedPlace.displayName(for: settingsStore.activeLanguage))
                                        .lineLimit(1)
                                }

                                if viewModel.isUsingManualLocation {
                                    Text(L10n.string(.mapPreviewManualLocationBadge, language: settingsStore.activeLanguage))
                                        .foregroundStyle(.orange)
                                }
                            }
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(.regularMaterial, in: Capsule())

#if os(iOS)
                            if let locationMessage = viewModel.locationMessage {
                                Text(locationMessage)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
#endif
                        }
                        .padding()
                    }
                    .overlay(alignment: .topTrailing) {
#if os(iOS)
                        if !isPickingLocation {
                            VStack(alignment: .trailing, spacing: 10) {
                                CompactMapActionButton(
                                    title: L10n.string(.mapPreviewRefresh, language: settingsStore.activeLanguage),
                                    systemImage: "arrow.clockwise",
                                    action: {
                                        Task {
                                            await viewModel.refreshData()
                                        }
                                    }
                                )

                                CompactMapActionButton(
                                    title: L10n.string(.mapPreviewUseMyLocation, language: settingsStore.activeLanguage),
                                    systemImage: "location",
                                    action: {
                                        isPickingLocation = false
                                        Task {
                                            await viewModel.requestOrRefreshLocation()
                                        }
                                    }
                                )

                                CompactMapActionButton(
                                    title: L10n.string(.mapPreviewPickLocation, language: settingsStore.activeLanguage),
                                    systemImage: "mappin.and.ellipse",
                                    action: {
                                        isPickingLocation = true
                                    }
                                )

                                Picker("", selection: $viewModel.travelMode) {
                                    ForEach(MapPreviewTravelMode.allCases) { mode in
                                        Text(L10n.string(mode.localizationKey, language: settingsStore.activeLanguage))
                                            .tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .padding(8)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .frame(maxWidth: 220)
                            }
                            .padding()
                        }
#endif
                    }
                    .overlay {
#if os(macOS)
                        MacMapRightClickMonitor { point in
                            guard let coordinate = proxy.convert(point, from: .local) else {
                                return
                            }

                            Task {
                                await viewModel.setManualLocation(
                                    coordinate: GeoCoordinate(
                                        latitude: coordinate.latitude,
                                        longitude: coordinate.longitude
                                    )
                                )
                            }
                        }
                        .allowsHitTesting(false)
#endif
                    }
                    .overlay {
                        if isPickingLocation {
                            MapPreviewCenterPickerOverlay(
                                preview: viewModel.mapCenterPreview(language: settingsStore.activeLanguage),
                                onUseCenter: {
                                    Task {
                                        await viewModel.useVisibleMapCenterAsCurrentLocation()
                                        isPickingLocation = false
                                    }
                                },
                                onCancel: {
                                    isPickingLocation = false
                                },
                                language: settingsStore.activeLanguage
                            )
                        }
                    }
                }
            }

            if !isPickingLocation {
                MapPreviewBottomPanel(
                    selectedPlace: viewModel.selectedPlace,
                    activeRouteCandidate: viewModel.activeRouteCandidate,
                    alternativeRouteCandidates: viewModel.alternativeRouteCandidates,
                    routeClusterWarning: viewModel.routeClusterWarning,
                    navigationPhase: viewModel.navigationPhase,
                    currentLocation: viewModel.effectiveLocation,
                    authorizationStatus: viewModel.authorizationStatus,
                    isUsingManualLocation: viewModel.isUsingManualLocation,
                    language: settingsStore.activeLanguage,
                    onStartNavigation: { candidateID in
                        Task {
                            await viewModel.startNavigation(candidateID: candidateID)
                        }
                    },
                    onSwitchRoute: { candidateID in
                        Task {
                            await viewModel.switchActiveRoute(candidateID: candidateID)
                        }
                    },
                    onStopNavigation: {
                        viewModel.stopNavigation()
                    }
                )
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
        }
    }

    @MapContentBuilder
    private var mapContent: some MapContent {
        ForEach(mapDisplayedPlaces) { place in
            Annotation(
                place.displayName(for: settingsStore.activeLanguage),
                coordinate: place.routingCoordinate.locationCoordinate,
                anchor: .center
            ) {
                Button {
                    Task {
                        await viewModel.selectPlace(id: place.id)
                    }
                } label: {
                    ShelterMarker(isSelected: place.id == viewModel.selectedPlace?.id)
                }
                .buttonStyle(.plain)
            }
        }

        if let selectedPlace = viewModel.selectedPlace {
            Annotation(
                selectedPlace.displayName(for: settingsStore.activeLanguage),
                coordinate: selectedPlace.objectCoordinate.locationCoordinate,
                anchor: .center
            ) {
                SelectedObjectMarker()
            }
        }

        ForEach(viewModel.routeTargetOptions) { option in
            Annotation(
                option.pointTitle(language: settingsStore.activeLanguage),
                coordinate: option.coordinate.locationCoordinate,
                anchor: .center
            ) {
                Button {
                    Task {
                        await viewModel.selectRouteTarget(id: option.id)
                    }
                } label: {
                    RouteTargetMarker(
                        isSelected: option.id == viewModel.selectedRouteTarget?.id,
                        systemImage: option.symbolName
                    )
                }
                .buttonStyle(.plain)
            }
        }

        if let currentLocation = viewModel.effectiveLocation {
            Annotation(
                L10n.string(.mapPreviewCurrentLocation, language: settingsStore.activeLanguage),
                coordinate: currentLocation.coordinate.locationCoordinate,
                anchor: .center
            ) {
                CurrentLocationMarker(isManual: viewModel.isUsingManualLocation)
            }
        }

        if !viewModel.objectConnectorCoordinates.isEmpty {
            MapPolyline(coordinates: viewModel.objectConnectorCoordinates)
                .stroke(
                    Color.teal.opacity(0.75),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [7, 5])
                )
        }

        ForEach(Array(viewModel.routeCandidates.enumerated()), id: \.element.id) { index, candidate in
            if !candidate.polylineCoordinates.isEmpty {
                MapPolyline(coordinates: candidate.polylineCoordinates)
                    .stroke(
                        viewModel.routeColor(forRank: index, candidateID: candidate.id),
                        style: StrokeStyle(
                            lineWidth: candidate.id == viewModel.activeRouteCandidateID ? 7 : 4,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
            }
        }

        if !viewModel.routePolylineCoordinates.isEmpty, !viewModel.isShowingActiveRoute {
            MapPolyline(coordinates: viewModel.routePolylineCoordinates)
                .stroke(
                    Color.accentColor,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
                )
        }
    }
}

private struct CompactMapActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .fixedSize(horizontal: true, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct MacPhonePreviewShell<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { geometry in
            let phoneSize = previewSize(in: geometry.size)

            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.94, green: 0.97, blue: 0.99),
                        Color(red: 0.85, green: 0.91, blue: 0.97)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.55))
                            .frame(width: 420, height: 420)
                            .offset(x: -180, y: -220)

                        Circle()
                            .fill(Color.cyan.opacity(0.10))
                            .frame(width: 360, height: 360)
                            .offset(x: 220, y: 180)
                    }
                }

                VStack {
                    Spacer()

                    ZStack(alignment: .top) {
                        RoundedRectangle(cornerRadius: 54, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.black.opacity(0.96),
                                        Color(red: 0.13, green: 0.15, blue: 0.19)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: phoneSize.width, height: phoneSize.height)
                            .shadow(color: .black.opacity(0.30), radius: 40, y: 18)

                        RoundedRectangle(cornerRadius: 46, style: .continuous)
                            .fill(Color.black)
                            .frame(width: phoneSize.width - 16, height: phoneSize.height - 16)
                            .overlay {
                                content
                                    .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                                    .padding(8)
                            }
                            .padding(.top, 8)

                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.black.opacity(0.88))
                            .frame(width: 132, height: 34)
                            .overlay {
                                Capsule()
                                    .fill(Color.white.opacity(0.10))
                                    .frame(width: 72, height: 10)
                            }
                            .padding(.top, 18)

                        Capsule()
                            .fill(Color.white.opacity(0.16))
                            .frame(width: 140, height: 5)
                            .padding(.top, phoneSize.height - 28)
                    }

                    Spacer()
                }
                .padding(24)
            }
        }
    }

    private func previewSize(in availableSize: CGSize) -> CGSize {
        let maxHeight = min(availableSize.height - 56, 860)
        let height = max(640, maxHeight)
        return CGSize(width: height * 0.46, height: height)
    }
}

@MainActor
private final class MapPreviewViewModel: ObservableObject {
    @Published private(set) var places: [CanonicalPlace] = []
    @Published private(set) var selectedPlace: CanonicalPlace?
    @Published private(set) var routeCandidates: [MapRouteCandidate] = []
    @Published private(set) var activeRouteCandidateID: String?
    @Published private(set) var isNavigationActive = false
    @Published private(set) var navigationPhase: MapPreviewNavigationPhase = .selection
    @Published private(set) var routeTargetOptions: [MapRouteTargetOption] = []
    @Published private(set) var selectedRouteTarget: MapRouteTargetOption?
    @Published private(set) var currentLocation: LocationSnapshot?
    @Published private(set) var manualLocation: LocationSnapshot?
    @Published private(set) var authorizationStatus: LocationAuthorizationStatus = .notDetermined
    @Published private(set) var routeSummary: MapRouteSummary?
    @Published private(set) var routeLineKind: MapPreviewRouteLineKind?
    @Published private(set) var routePolylineCoordinates: [CLLocationCoordinate2D] = []
    @Published private(set) var routeClusterWarning: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingRoute = false
    @Published var cameraPosition: MapCameraPosition = .automatic
    @Published var travelMode: MapPreviewTravelMode = .walking

    private var visibleRegion: MKCoordinateRegion?

    private let placeRepository: CanonicalPlaceRepository
    private let routingPointRepository: RoutingPointRepository
    private let locationService: LocationService
    private let routingTargetSelector: PreferredRoutingPointSelecting
    private let languageProvider: () -> AppLanguage
    private let initialPreferredCity: String?

    private var hasLoaded = false
    private var didAttemptLocationRefresh = false
    private var nearestRoutesRefreshSequence = 0
    private var locationUpdatesTask: Task<Void, Never>?
    private var activeRoutePinnedByUser = false
    private var lastLiveRefreshLocation: LocationSnapshot?

    private let liveRefreshDistanceThresholdMeters = 12.0
    private let arrivalThresholdMeters = 35.0

    init(
        placeRepository: CanonicalPlaceRepository,
        routingPointRepository: RoutingPointRepository,
        locationService: LocationService,
        routingTargetSelector: PreferredRoutingPointSelecting = PreferredRoutingPointSelector(),
        initialPreferredCity: String? = nil,
        languageProvider: @escaping () -> AppLanguage
    ) {
        self.placeRepository = placeRepository
        self.routingPointRepository = routingPointRepository
        self.locationService = locationService
        self.routingTargetSelector = routingTargetSelector
        self.initialPreferredCity = initialPreferredCity
        self.languageProvider = languageProvider
    }

    deinit {
        locationUpdatesTask?.cancel()
    }

    var locationMessage: String? {
        let language = languageProvider()

        switch authorizationStatus {
        case .notDetermined:
            return L10n.string(.nearbyLocationPermissionPrompt, language: language)
        case .denied, .restricted:
            return L10n.string(.nearbyLocationDenied, language: language)
        case .authorized:
            guard didAttemptLocationRefresh, currentLocation == nil else {
                return nil
            }

            return L10n.string(.nearbyLocationUnavailable, language: language)
        }
    }

    var effectiveLocation: LocationSnapshot? {
        manualLocation ?? currentLocation
    }

    var isUsingManualLocation: Bool {
        manualLocation != nil
    }

    var objectConnectorCoordinates: [CLLocationCoordinate2D] {
        guard
            let selectedPlace,
            let selectedRouteTarget,
            selectedPlace.objectCoordinate != selectedRouteTarget.coordinate
        else {
            return []
        }

        return [
            selectedPlace.objectCoordinate.locationCoordinate,
            selectedRouteTarget.coordinate.locationCoordinate
        ]
    }

    var activeRouteCandidate: MapRouteCandidate? {
        routeCandidates.first(where: { $0.id == activeRouteCandidateID })
    }

    var alternativeRouteCandidates: [MapRouteCandidate] {
        routeCandidates.filter { $0.id != activeRouteCandidateID }
    }

    var isShowingActiveRoute: Bool {
        routeCandidates.contains { $0.id == activeRouteCandidateID }
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await refreshData()
    }

    func refreshData() async {
        isLoading = true
        errorMessage = nil

        authorizationStatus = await locationService.authorizationStatus()

        do {
            places = try placeRepository.fetchAll(limit: nil)
            errorMessage = nil

            if let selectedID = selectedPlace?.id {
                await selectPlace(id: selectedID)
            } else if let preferredID = preferredInitialPlaceID(in: places) {
                await selectPlace(id: preferredID)
            } else {
                selectedPlace = nil
                routeTargetOptions = []
                selectedRouteTarget = nil
                routePolylineCoordinates = []
                routeSummary = nil
                routeLineKind = nil
                routeClusterWarning = nil
                activeRouteCandidateID = nil
                navigationPhase = .selection
                updateCamera()
            }
        } catch {
            errorMessage = error.localizedDescription
            places = []
            selectedPlace = nil
            routeTargetOptions = []
            selectedRouteTarget = nil
        }

        if authorizationStatus == .authorized {
            await refreshLocation()
            startObservingLocationUpdates()
        } else {
            stopObservingLocationUpdates()
        }

        isLoading = false
    }

    func handleDatasetDidSync() async {
        routeCandidates = []
        activeRouteCandidateID = nil
        activeRoutePinnedByUser = false
        isNavigationActive = false
        navigationPhase = .selection
        routeClusterWarning = nil
        routePolylineCoordinates = []
        routeSummary = nil
        routeLineKind = nil
        routeTargetOptions = []
        selectedRouteTarget = nil
        selectedPlace = nil

        await refreshData()
    }

    func requestOrRefreshLocation() async {
        didAttemptLocationRefresh = true

        let currentStatus = await locationService.authorizationStatus()
        if currentStatus == .notDetermined {
            authorizationStatus = await locationService.requestPermission()
        } else {
            authorizationStatus = currentStatus
        }

        guard authorizationStatus == .authorized else {
            currentLocation = nil
            manualLocation = nil
            routeCandidates = []
            activeRouteCandidateID = nil
            isNavigationActive = false
            navigationPhase = .selection
            activeRoutePinnedByUser = false
            stopObservingLocationUpdates()
            await refreshRoute()
            updateCamera()
            return
        }

        manualLocation = nil
        await refreshLocation()
        startObservingLocationUpdates()
    }

    func selectPlace(id: UUID?) async {
        guard let id, let place = places.first(where: { $0.id == id }) else {
            selectedPlace = nil
            routeTargetOptions = []
            selectedRouteTarget = nil
            routePolylineCoordinates = []
            routeSummary = nil
            routeLineKind = nil
            activeRouteCandidateID = nil
            navigationPhase = .selection
            updateCamera()
            return
        }

        selectedPlace = place

        do {
            let routingPoints = try routingPointRepository.fetchRoutingPoints(for: id)
            errorMessage = nil
            routeTargetOptions = makeRouteTargetOptions(for: place, routingPoints: routingPoints)
            let resolvedTarget = routingTargetSelector.resolve(for: place, routingPoints: routingPoints)
            selectedRouteTarget = routeTargetOptions.first {
                $0.coordinate == resolvedTarget.coordinate
                && $0.pointType == resolvedTarget.pointType
                && $0.source == resolvedTarget.source
            } ?? routeTargetOptions.first
            if !isNavigationActive {
                activeRouteCandidateID = routeCandidates.first(where: {
                    $0.place.id == place.id && $0.target.id == selectedRouteTarget?.id
                })?.id
            }
            await refreshRoute()
        } catch {
            errorMessage = error.localizedDescription
            routeTargetOptions = []
            selectedRouteTarget = nil
            routePolylineCoordinates = []
            routeSummary = nil
            routeLineKind = nil
            activeRouteCandidateID = nil
            navigationPhase = .selection
            updateCamera()
        }
    }

    func selectRouteTarget(id: String) async {
        selectedRouteTarget = routeTargetOptions.first(where: { $0.id == id })
        if !isNavigationActive {
            activeRouteCandidateID = routeCandidates.first(where: {
                $0.place.id == selectedPlace?.id && $0.target.id == id
            })?.id
        }
        await refreshRoute()
    }

    func startNavigation(candidateID: String) async {
        guard let candidate = routeCandidates.first(where: { $0.id == candidateID }) else {
            return
        }

        isNavigationActive = true
        activeRoutePinnedByUser = true
        activeRouteCandidateID = candidate.id
        applyActiveCandidateLocally(candidate)
        updateNavigationPhase(with: candidate)
        await refreshNearestRouteCandidates()
    }

    func switchActiveRoute(candidateID: String) async {
        guard let candidate = routeCandidates.first(where: { $0.id == candidateID }) else {
            return
        }

        isNavigationActive = true
        activeRoutePinnedByUser = true
        activeRouteCandidateID = candidate.id
        applyActiveCandidateLocally(candidate)
        updateNavigationPhase(with: candidate)
        await refreshNearestRouteCandidates()
    }

    func stopNavigation() {
        isNavigationActive = false
        activeRoutePinnedByUser = false
        navigationPhase = .selection

        if let fallbackCandidate = routeCandidates.first {
            activeRouteCandidateID = fallbackCandidate.id
            applyActiveCandidateLocally(fallbackCandidate)
        } else {
            activeRouteCandidateID = nil
        }

        updateCamera()
    }

    func refreshForTravelModeChange() async {
        if effectiveLocation != nil {
            await refreshNearestRouteCandidates()
        } else {
            await refreshRoute()
        }
    }

    func updateVisibleRegion(_ region: MKCoordinateRegion) {
        visibleRegion = region
    }

    func mapCenterPreview(language: AppLanguage) -> MapCenterPreview? {
        guard let visibleRegion else {
            return nil
        }

        let center = GeoCoordinate(
            latitude: visibleRegion.center.latitude,
            longitude: visibleRegion.center.longitude
        )

        let nearest = places
            .map { place in
                (
                    place: place,
                    distance: DistanceCalculator.meters(from: center, to: place.routingCoordinate)
                )
            }
            .min { lhs, rhs in
                if lhs.distance == rhs.distance {
                    return lhs.place.updatedAt > rhs.place.updatedAt
                }

                return lhs.distance < rhs.distance
            }

        return MapCenterPreview(
            coordinate: center,
            currentCoordinate: effectiveLocation?.coordinate,
            nearestPlaceTitle: nearest?.place.displayName(for: language),
            nearestPlaceDistanceMeters: nearest?.distance
        )
    }

    func useVisibleMapCenterAsCurrentLocation() async {
        guard let visibleRegion else { return }

        await setManualLocation(
            coordinate: GeoCoordinate(
                latitude: visibleRegion.center.latitude,
                longitude: visibleRegion.center.longitude
            )
        )
    }

    func setManualLocation(coordinate: GeoCoordinate) async {
        manualLocation = LocationSnapshot(
            coordinate: coordinate,
            timestamp: Date()
        )
        lastLiveRefreshLocation = manualLocation

        await refreshNearestRouteCandidates()
        if routeCandidates.isEmpty {
            await refreshRoute()
        }
        updateCamera()
    }

    func clearManualLocation() async {
        guard manualLocation != nil else { return }
        manualLocation = nil

        if currentLocation != nil {
            await refreshNearestRouteCandidates()
            if routeCandidates.isEmpty {
                await refreshRoute()
            }
        } else {
            routeCandidates = []
            activeRouteCandidateID = nil
            isNavigationActive = false
            navigationPhase = .selection
            await refreshRoute()
        }

        updateCamera()
    }

    func refreshRoute() async {
        routePolylineCoordinates = []
        routeSummary = nil
        routeLineKind = nil

        guard
            let selectedPlace,
            let selectedRouteTarget
        else {
            navigationPhase = isNavigationActive ? .activeNavigation : .selection
            updateCamera()
            return
        }

        guard let effectiveLocation else {
            routeSummary = MapRouteSummary(
                distanceMeters: DistanceCalculator.meters(
                    from: selectedPlace.objectCoordinate,
                    to: selectedRouteTarget.coordinate
                ),
                expectedTravelTime: nil
            )
            updateNavigationPhase()
            updateCamera()
            return
        }

        isLoadingRoute = true
        defer { isLoadingRoute = false }

        let request = MKDirections.Request()
        request.source = MKMapItem(
            location: CLLocation(
                latitude: effectiveLocation.coordinate.latitude,
                longitude: effectiveLocation.coordinate.longitude
            ),
            address: nil
        )
        request.destination = MKMapItem(
            location: CLLocation(
                latitude: selectedRouteTarget.coordinate.latitude,
                longitude: selectedRouteTarget.coordinate.longitude
            ),
            address: nil
        )
        request.transportType = travelMode.transportType
        request.requestsAlternateRoutes = false

        do {
            let response = try await MKDirections(request: request).calculate()

            if let route = response.routes.first {
                routePolylineCoordinates = route.polyline.coordinates
                routeSummary = MapRouteSummary(
                    distanceMeters: route.distance,
                    expectedTravelTime: route.expectedTravelTime
                )
                routeLineKind = .turnByTurn
            } else {
                applyFallbackRoute(
                    from: effectiveLocation.coordinate,
                    to: selectedRouteTarget.coordinate
                )
            }
        } catch {
            applyFallbackRoute(
                from: effectiveLocation.coordinate,
                to: selectedRouteTarget.coordinate
            )
        }

        updateNavigationPhase()
        updateCamera()
    }

    func filteredPlaces(matching searchText: String, language: AppLanguage) -> [CanonicalPlace] {
        let normalizedQuery = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let filtered = places.filter { place in
            guard !normalizedQuery.isEmpty else {
                return true
            }

            let haystack = [
                place.displayName(for: language),
                place.displayAddress(for: language),
                place.city ?? ""
            ]
                .joined(separator: " ")
                .lowercased()

            return haystack.contains(normalizedQuery)
        }

        return filtered.sorted { lhs, rhs in
            switch (distanceToPlace(lhs), distanceToPlace(rhs)) {
            case let (leftDistance?, rightDistance?):
                if leftDistance == rightDistance {
                    return lhs.updatedAt > rhs.updatedAt
                }

                return leftDistance < rightDistance
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return lhs.updatedAt > rhs.updatedAt
            }
        }
    }

    func mapPlaces(matching searchText: String, language: AppLanguage) -> [CanonicalPlace] {
        let filtered = filteredPlaces(matching: searchText, language: language)
        let normalizedQuery = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let isSearching = !normalizedQuery.isEmpty
        let limit = isSearching ? 60 : 80

        if let effectiveLocation {
            return Array(
                filtered
                    .sorted { lhs, rhs in
                        let lhsDistance = DistanceCalculator.meters(
                            from: effectiveLocation.coordinate,
                            to: lhs.routingCoordinate
                        )
                        let rhsDistance = DistanceCalculator.meters(
                            from: effectiveLocation.coordinate,
                            to: rhs.routingCoordinate
                        )

                        if lhsDistance == rhsDistance {
                            return lhs.updatedAt > rhs.updatedAt
                        }

                        return lhsDistance < rhsDistance
                    }
                    .prefix(limit)
            )
        }

        if isSearching {
            return Array(filtered.prefix(limit))
        }

        if let selectedPlace {
            return [selectedPlace]
        }

        return []
    }

    func distanceToPlace(_ place: CanonicalPlace) -> Double? {
        guard let effectiveLocation else {
            return nil
        }

        return DistanceCalculator.meters(
            from: effectiveLocation.coordinate,
            to: place.routingCoordinate
        )
    }

    func isRelevantForEmergencyAccess(_ place: CanonicalPlace) -> Bool {
        guard let distance = distanceToPlace(place) else {
            return true
        }

        return ShelterAccessPolicy.isWithinEmergencyWalkingWindow(distanceMeters: distance)
    }

    private func refreshLocation() async {
        do {
            currentLocation = try await locationService.currentLocation()
        } catch {
            currentLocation = nil
        }

        lastLiveRefreshLocation = currentLocation

        await refreshNearestRouteCandidates()
        if routeCandidates.isEmpty {
            await refreshRoute()
        }
    }

    private func applyFallbackRoute(from origin: GeoCoordinate, to destination: GeoCoordinate) {
        routePolylineCoordinates = [
            origin.locationCoordinate,
            destination.locationCoordinate
        ]
        routeSummary = MapRouteSummary(
            distanceMeters: DistanceCalculator.meters(from: origin, to: destination),
            expectedTravelTime: travelMode == .walking
                ? TimeInterval(DistanceCalculator.estimatedWalkingMinutes(forMeters: DistanceCalculator.meters(from: origin, to: destination)) * 60)
                : nil
        )
        routeLineKind = .estimatedStraightLine
    }

    private func makeRouteTargetOptions(
        for place: CanonicalPlace,
        routingPoints: [RoutingPoint]
    ) -> [MapRouteTargetOption] {
        var options: [MapRouteTargetOption] = []

        if let entranceCoordinate = place.entranceCoordinate, place.status != .removed {
            options.append(
                MapRouteTargetOption(
                    id: "place-entrance",
                    coordinate: entranceCoordinate,
                    pointType: .entrance,
                    source: .placeEntrance
                )
            )
        }

        options.append(
            contentsOf: routingPoints.map {
                MapRouteTargetOption(
                    id: $0.id.uuidString,
                    coordinate: $0.coordinate,
                    pointType: $0.pointType,
                    source: .routingPoint
                )
            }
        )

        if let preferredCoordinate = place.preferredRoutingCoordinate {
            options.append(
                MapRouteTargetOption(
                    id: "place-preferred",
                    coordinate: preferredCoordinate,
                    pointType: place.preferredRoutingPointType ?? .preferred,
                    source: .storedPreferred
                )
            )
        }

        options.append(
            MapRouteTargetOption(
                id: "place-object",
                coordinate: place.objectCoordinate,
                pointType: .object,
                source: .objectFallback
            )
        )

        var seen = Set<String>()
        return options.filter { option in
            let key = "\(option.coordinate.latitude)-\(option.coordinate.longitude)-\(option.pointType.rawValue)-\(option.source.rawValue)"
            return seen.insert(key).inserted
        }
    }

    private func updateCamera() {
        var coordinates: [CLLocationCoordinate2D] = []

        if isNavigationActive, let activeRouteCandidate {
            coordinates.append(contentsOf: activeRouteCandidate.polylineCoordinates)
            coordinates.append(activeRouteCandidate.place.objectCoordinate.locationCoordinate)
            coordinates.append(activeRouteCandidate.target.coordinate.locationCoordinate)

            for candidate in alternativeRouteCandidates {
                coordinates.append(candidate.target.coordinate.locationCoordinate)
            }
        } else {
            for candidate in routeCandidates {
                coordinates.append(contentsOf: candidate.polylineCoordinates)
                coordinates.append(candidate.place.objectCoordinate.locationCoordinate)
                coordinates.append(candidate.target.coordinate.locationCoordinate)
            }
        }

        if !routePolylineCoordinates.isEmpty {
            coordinates.append(contentsOf: routePolylineCoordinates)
        }

        if let selectedPlace {
            coordinates.append(selectedPlace.objectCoordinate.locationCoordinate)
        }

        if let selectedRouteTarget {
            coordinates.append(selectedRouteTarget.coordinate.locationCoordinate)
        }

        if let effectiveLocation {
            coordinates.append(effectiveLocation.coordinate.locationCoordinate)
        }

        guard !coordinates.isEmpty else {
            cameraPosition = .automatic
            return
        }

        cameraPosition = .region(MKCoordinateRegion.fitting(coordinates))
    }

    func routeColor(forRank rank: Int, candidateID: String) -> Color {
        let palette: [Color] = [.accentColor, .orange, .mint]
        let base = palette[rank % palette.count]
        if candidateID == activeRouteCandidateID {
            return base
        }

        return isNavigationActive ? base.opacity(0.42) : base.opacity(0.72)
    }

    private func refreshNearestRouteCandidates() async {
        guard let effectiveLocation else {
            routeCandidates = []
            activeRouteCandidateID = nil
            navigationPhase = .selection
            routeClusterWarning = nil
            return
        }

        let refreshID = nearestRoutesRefreshSequence + 1
        nearestRoutesRefreshSequence = refreshID

        let sortedByDistance = places
            .map { place in
                (
                    place: place,
                    directDistance: DistanceCalculator.meters(
                        from: effectiveLocation.coordinate,
                        to: place.routingCoordinate
                    )
                )
            }
            .sorted { $0.directDistance < $1.directDistance }

        let inferredLocalCity = sortedByDistance.first?.place.city?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedLocalCity = inferredLocalCity?.isEmpty == false ? inferredLocalCity : nil

        let localMatches = sortedByDistance.filter { item in
            guard let normalizedLocalCity else {
                return false
            }

            return item.place.city?.caseInsensitiveCompare(normalizedLocalCity) == .orderedSame
        }

        let neighborMatches = sortedByDistance.filter { item in
            guard let normalizedLocalCity else {
                return true
            }

            return item.place.city?.caseInsensitiveCompare(normalizedLocalCity) != .orderedSame
        }

        let shortlist = Array((localMatches + neighborMatches).prefix(12))

        guard !shortlist.isEmpty else {
            routeCandidates = []
            activeRouteCandidateID = nil
            navigationPhase = .selection
            routeClusterWarning = nil
            return
        }

        routeClusterWarning = MapPreviewNavigationStateResolver.routeClusterWarning(
            localCity: normalizedLocalCity,
            localCandidateCount: localMatches.count,
            requestedCandidateCount: 3,
            language: languageProvider()
        )

        isLoadingRoute = true
        defer { isLoadingRoute = false }

        var candidates: [MapRouteCandidate] = []
        for item in shortlist {
            guard refreshID == nearestRoutesRefreshSequence else { return }

            let routingPoints = (try? routingPointRepository.fetchRoutingPoints(for: item.place.id)) ?? []
            let availableTargets = makeRouteTargetOptions(for: item.place, routingPoints: routingPoints)
            let resolvedTarget = routingTargetSelector.resolve(for: item.place, routingPoints: routingPoints)
            let selectedTarget = availableTargets.first {
                $0.coordinate == resolvedTarget.coordinate
                && $0.pointType == resolvedTarget.pointType
                && $0.source == resolvedTarget.source
            } ?? availableTargets.first ?? MapRouteTargetOption(
                id: "place-object",
                coordinate: item.place.objectCoordinate,
                pointType: .object,
                source: .objectFallback
            )

            let resolvedRoute = await calculateRoute(
                from: effectiveLocation.coordinate,
                to: selectedTarget.coordinate
            )

            candidates.append(
                MapRouteCandidate(
                    id: "\(item.place.id.uuidString)-\(selectedTarget.id)",
                    place: item.place,
                    target: selectedTarget,
                    availableTargets: availableTargets,
                    summary: resolvedRoute.summary,
                    lineKind: resolvedRoute.lineKind,
                    polylineCoordinates: resolvedRoute.polylineCoordinates,
                    directDistanceMeters: item.directDistance
                )
            )
        }

        guard refreshID == nearestRoutesRefreshSequence else { return }

        let sortedCandidates = candidates.sorted { MapRouteCandidate.routePriority(lhs: $0, rhs: $1) }
        routeCandidates = MapPreviewNavigationStateResolver.visibleCandidates(
            sortedCandidates: sortedCandidates,
            activeRouteCandidateID: activeRoutePinnedByUser ? activeRouteCandidateID : nil
        )

        let nextSelectionID = MapPreviewNavigationStateResolver.nextActiveRouteCandidateID(
            currentActiveRouteCandidateID: activeRouteCandidateID,
            visibleCandidates: routeCandidates,
            preserveCurrentSelection: activeRoutePinnedByUser
        )
        activeRouteCandidateID = nextSelectionID

        if let nextSelectionID {
            guard let nextCandidate = routeCandidates.first(where: { $0.id == nextSelectionID }) else {
                return
            }

            applyActiveCandidateLocally(nextCandidate)
            updateNavigationPhase(with: nextCandidate)
        } else {
            updateNavigationPhase()
        }

        updateCamera()
    }

    func handleLocationUpdate(_ snapshot: LocationSnapshot) async {
        currentLocation = snapshot

        guard manualLocation == nil else {
            return
        }

        guard shouldRefreshRouteCandidates(for: snapshot) else {
            updateNavigationPhase()
            return
        }

        lastLiveRefreshLocation = snapshot
        await refreshNearestRouteCandidates()

        if routeCandidates.isEmpty {
            await refreshRoute()
        }
    }

    private func applyActiveCandidateLocally(_ candidate: MapRouteCandidate) {
        selectedPlace = candidate.place
        routeTargetOptions = candidate.availableTargets
        selectedRouteTarget = candidate.target
        routePolylineCoordinates = candidate.polylineCoordinates
        routeSummary = candidate.summary
        routeLineKind = candidate.lineKind
        errorMessage = nil
        updateCamera()
    }

    private func updateNavigationPhase(with candidate: MapRouteCandidate? = nil) {
        guard isNavigationActive else {
            navigationPhase = .selection
            return
        }

        guard let effectiveLocation, let activeCandidate = candidate ?? activeRouteCandidate else {
            navigationPhase = .activeNavigation
            return
        }

        let remainingDistance = DistanceCalculator.meters(
            from: effectiveLocation.coordinate,
            to: activeCandidate.target.coordinate
        )
        navigationPhase = MapPreviewNavigationStateResolver.phase(
            remainingDistanceMeters: remainingDistance,
            arrivalThresholdMeters: arrivalThresholdMeters
        )
    }

    private func shouldRefreshRouteCandidates(for snapshot: LocationSnapshot) -> Bool {
        guard let lastLiveRefreshLocation else {
            return true
        }

        return DistanceCalculator.meters(
            from: lastLiveRefreshLocation.coordinate,
            to: snapshot.coordinate
        ) >= liveRefreshDistanceThresholdMeters
    }

    private func startObservingLocationUpdates() {
        guard locationUpdatesTask == nil else {
            return
        }

        locationUpdatesTask = Task { [weak self] in
            guard let self else { return }

            do {
                for try await snapshot in self.locationService.locationUpdates() {
                    await self.handleLocationUpdate(snapshot)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func stopObservingLocationUpdates() {
        locationUpdatesTask?.cancel()
        locationUpdatesTask = nil
    }

    private func calculateRoute(from origin: GeoCoordinate, to destination: GeoCoordinate) async -> ResolvedPreviewRoute {
        let request = MKDirections.Request()
        request.source = MKMapItem(
            location: CLLocation(latitude: origin.latitude, longitude: origin.longitude),
            address: nil
        )
        request.destination = MKMapItem(
            location: CLLocation(latitude: destination.latitude, longitude: destination.longitude),
            address: nil
        )
        request.transportType = travelMode.transportType
        request.requestsAlternateRoutes = false

        do {
            let response = try await MKDirections(request: request).calculate()
            if let route = response.routes.first {
                return ResolvedPreviewRoute(
                    summary: MapRouteSummary(
                        distanceMeters: route.distance,
                        expectedTravelTime: route.expectedTravelTime
                    ),
                    lineKind: .turnByTurn,
                    polylineCoordinates: route.polyline.coordinates
                )
            }
        } catch {
        }

        return ResolvedPreviewRoute(
            summary: MapRouteSummary(
                distanceMeters: DistanceCalculator.meters(from: origin, to: destination),
                expectedTravelTime: travelMode == .walking
                    ? TimeInterval(DistanceCalculator.estimatedWalkingMinutes(forMeters: DistanceCalculator.meters(from: origin, to: destination)) * 60)
                    : nil
            ),
            lineKind: .estimatedStraightLine,
            polylineCoordinates: [
                origin.locationCoordinate,
                destination.locationCoordinate
            ]
        )
    }

    private func preferredInitialPlaceID(in places: [CanonicalPlace]) -> UUID? {
        guard let initialPreferredCity else {
            return nil
        }

        return places.first(where: {
            ($0.city ?? "").caseInsensitiveCompare(initialPreferredCity) == .orderedSame
        })?.id
    }
}

private struct MapPreviewPlaceRow: View {
    let place: CanonicalPlace
    let isSelected: Bool
    let distanceMeters: Double?
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.displayName(for: language))
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    let address = place.displayAddress(for: language)
                    if !address.isEmpty {
                        Text(address)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 8)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }

            HStack(spacing: 10) {
                Label(
                    L10n.string(place.placeType.localizationKey, language: language),
                    systemImage: "building.2"
                )

                if let distanceMeters {
                    Label(L10n.formatDistance(distanceMeters), systemImage: "figure.walk")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct MapPreviewNearestRouteRow: View {
    let rank: Int
    let candidate: MapRouteCandidate
    let isSelected: Bool
    let isActive: Bool
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Text("\(rank)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.accentColor, in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(candidate.place.displayName(for: language))
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    let address = candidate.place.displayAddress(for: language)
                    if !address.isEmpty {
                        Text(address)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 8)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }

            HStack(spacing: 10) {
                Label(
                    candidate.target.pointTitle(language: language),
                    systemImage: candidate.target.symbolName
                )

                Label(L10n.formatDistance(candidate.summary.distanceMeters, language: language), systemImage: "point.topleft.down.curvedto.point.bottomright.up")

                if let travelTime = candidate.summary.expectedTravelTime {
                    Label(travelTime.formattedRouteDuration(), systemImage: "clock")
                }

                if isActive {
                    Label(navigationStatusText(for: .activeNavigation, language: language), systemImage: "location.north.line")
                } else if isSelected {
                    Label(L10n.string(.mapPreviewSelectedRoute, language: language), systemImage: "checkmark")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct MapPreviewRouteTargetRow: View {
    let option: MapRouteTargetOption
    let isSelected: Bool
    let selectedPlace: CanonicalPlace
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Label(option.pointTitle(language: language), systemImage: option.symbolName)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                if isSelected {
                    Image(systemName: "location.north.line.fill")
                        .foregroundStyle(.orange)
                }
            }

            Text(L10n.string(option.source.localizationKey, language: language))
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(option.coordinate.formattedString())
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            let offset = DistanceCalculator.meters(from: selectedPlace.objectCoordinate, to: option.coordinate)
            if offset > 1 {
                Text(L10n.formatDistance(offset))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct MapPreviewBottomPanel: View {
    let selectedPlace: CanonicalPlace?
    let activeRouteCandidate: MapRouteCandidate?
    let alternativeRouteCandidates: [MapRouteCandidate]
    let routeClusterWarning: String?
    let navigationPhase: MapPreviewNavigationPhase
    let currentLocation: LocationSnapshot?
    let authorizationStatus: LocationAuthorizationStatus
    let isUsingManualLocation: Bool
    let language: AppLanguage
    let onStartNavigation: (String) -> Void
    let onSwitchRoute: (String) -> Void
    let onStopNavigation: () -> Void

    var body: some View {
        if let activeRouteCandidate {
            VStack(alignment: .leading, spacing: 10) {
                ActiveNavigationCard(
                    candidate: activeRouteCandidate,
                    routeClusterWarning: routeClusterWarning,
                    navigationPhase: navigationPhase,
                    currentLocation: currentLocation,
                    authorizationStatus: authorizationStatus,
                    isUsingManualLocation: isUsingManualLocation,
                    language: language,
                    onStartNavigation: { onStartNavigation(activeRouteCandidate.id) },
                    onStopNavigation: onStopNavigation
                )

                if navigationPhase != .arrived && !alternativeRouteCandidates.isEmpty {
                    AlternativeRoutesStrip(
                        candidates: Array(alternativeRouteCandidates.prefix(2)),
                        language: language,
                        onSelect: onSwitchRoute
                    )
                }
            }
            .frame(maxWidth: 520, alignment: .leading)
        } else if let selectedPlace {
            Text(selectedPlace.displayName(for: language))
                .font(.headline)
                .foregroundStyle(.primary)
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .frame(maxWidth: 520, alignment: .leading)
                .background(bottomPanelMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(panelStroke)
                .shadow(color: .black.opacity(0.08), radius: 18, y: 10)
        } else {
            Text(L10n.text(.mapPreviewNoSelection))
                .foregroundStyle(.secondary)
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .frame(maxWidth: 520, alignment: .leading)
                .background(bottomPanelMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(panelStroke)
                .shadow(color: .black.opacity(0.08), radius: 18, y: 10)
        }
    }

    private var bottomPanelMaterial: some ShapeStyle {
        .ultraThinMaterial
    }

    private var panelStroke: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .strokeBorder(Color.white.opacity(0.22))
    }
}

private struct ActiveNavigationCard: View {
    let candidate: MapRouteCandidate
    let routeClusterWarning: String?
    let navigationPhase: MapPreviewNavigationPhase
    let currentLocation: LocationSnapshot?
    let authorizationStatus: LocationAuthorizationStatus
    let isUsingManualLocation: Bool
    let language: AppLanguage
    let onStartNavigation: () -> Void
    let onStopNavigation: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(candidate.displayTitle(language: language))
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Text(navigationStatusText(for: navigationPhase, language: language))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(navigationPhase == .arrived ? .green : .blue)
                }

                Spacer(minLength: 8)

                HStack(spacing: 8) {
                    if navigationPhase == .selection {
                        Button(action: onStartNavigation) {
                            Label(startNavigationText(language: language), systemImage: "location.north.line")
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button(action: onStopNavigation) {
                            Label(stopNavigationText(language: language), systemImage: "xmark")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            HStack(spacing: 10) {
                RouteStatPill(
                    title: L10n.string(.mapPreviewRouteDistance, language: language),
                    value: L10n.formatDistance(candidate.summary.distanceMeters, language: language),
                    systemImage: "point.topleft.down.curvedto.point.bottomright.up"
                )

                if let expectedTravelTime = candidate.summary.expectedTravelTime {
                    RouteStatPill(
                        title: L10n.string(.mapPreviewRouteTravelTime, language: language),
                        value: expectedTravelTime.formattedRouteDuration(),
                        systemImage: "clock"
                    )
                }

                RouteStatPill(
                    title: L10n.string(.mapPreviewSelectedRoute, language: language),
                    value: candidate.target.pointTitle(language: language),
                    systemImage: candidate.target.symbolName
                )
            }

            HStack(spacing: 10) {
                Text(L10n.string(candidate.target.source.localizationKey, language: language))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if currentLocation != nil {
                    Label(
                        isUsingManualLocation
                            ? L10n.string(.mapPreviewPickedLocation, language: language)
                            : L10n.string(.mapPreviewCurrentLocation, language: language),
                        systemImage: "location.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else {
                    Text(
                        authorizationStatus == .authorized
                            ? L10n.string(.nearbyLocationUnavailable, language: language)
                            : L10n.string(.settingsNotAvailable, language: language)
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            if let routeClusterWarning {
                Label(routeClusterWarning, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(3)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.white.opacity(0.22))
        }
        .shadow(color: .black.opacity(0.10), radius: 18, y: 12)
    }
}

private struct AlternativeRoutesStrip: View {
    let candidates: [MapRouteCandidate]
    let language: AppLanguage
    let onSelect: (String) -> Void

    var body: some View {
        HStack(spacing: 10) {
            ForEach(candidates) { candidate in
                Button {
                    onSelect(candidate.id)
                } label: {
                    AlternativeRouteCard(candidate: candidate, language: language)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct AlternativeRouteCard: View {
    let candidate: MapRouteCandidate
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(candidate.displayTitle(language: language))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            HStack(spacing: 8) {
                Text(L10n.formatDistance(candidate.summary.distanceMeters, language: language))
                    .font(.caption.monospacedDigit())

                if let expectedTravelTime = candidate.summary.expectedTravelTime {
                    Text(expectedTravelTime.formattedRouteDuration())
                        .font(.caption.monospacedDigit())
                }
            }
            .foregroundStyle(.secondary)

            Label(candidate.target.pointTitle(language: language), systemImage: candidate.target.symbolName)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18))
        }
    }
}

private struct RouteStatPill: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.22), in: Capsule())
    }
}

private struct MapPreviewCenterPickerOverlay: View {
    let preview: MapCenterPreview?
    let onUseCenter: () -> Void
    let onCancel: () -> Void
    let language: AppLanguage

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.08)
                .ignoresSafeArea()

            VStack {
                VStack(spacing: 10) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.orange)
                        .padding(16)
                        .background(.regularMaterial, in: Circle())

                    Text(L10n.string(.mapPreviewPickLocationHint, language: language))
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

                    if let preview {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(preview.coordinate.formattedString(), systemImage: "location")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)

                            if let currentCoordinate = preview.currentCoordinate {
                                Label(currentCoordinate.formattedString(), systemImage: "location.fill")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }

                            if let nearestPlaceTitle = preview.nearestPlaceTitle,
                               let nearestPlaceDistanceMeters = preview.nearestPlaceDistanceMeters {
                                Label(
                                    "\(nearestPlaceTitle) • \(L10n.formatDistance(nearestPlaceDistanceMeters, language: language))",
                                    systemImage: "building.2"
                                )
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .frame(maxWidth: 320, alignment: .leading)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }

                Spacer()
            }
            .padding()

            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Label(L10n.string(.commonCancel, language: language), systemImage: "xmark")
                }
                .buttonStyle(.bordered)

                Button(action: onUseCenter) {
                    Label(L10n.string(.mapPreviewUseMapCenter, language: language), systemImage: "scope")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .allowsHitTesting(true)
    }
}

private struct MapCenterPreview {
    let coordinate: GeoCoordinate
    let currentCoordinate: GeoCoordinate?
    let nearestPlaceTitle: String?
    let nearestPlaceDistanceMeters: Double?
}

private struct ShelterMarker: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.accentColor : Color.blue.opacity(0.72))
                .frame(width: isSelected ? 18 : 12, height: isSelected ? 18 : 12)

            Circle()
                .stroke(Color.white.opacity(0.9), lineWidth: 2)
                .frame(width: isSelected ? 24 : 18, height: isSelected ? 24 : 18)
        }
        .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
    }
}

private struct SelectedObjectMarker: View {
    var body: some View {
        Image(systemName: "building.2.fill")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .padding(10)
            .background(Color.indigo, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.85), lineWidth: 2)
            }
            .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
    }
}

private struct RouteTargetMarker: View {
    let isSelected: Bool
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: isSelected ? 13 : 11, weight: .bold))
            .foregroundStyle(.white)
            .padding(isSelected ? 10 : 8)
            .background(
                isSelected ? Color.orange : Color.orange.opacity(0.78),
                in: RoundedRectangle(cornerRadius: isSelected ? 14 : 11, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: isSelected ? 14 : 11, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.9), lineWidth: 2)
            }
            .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
    }
}

#if os(macOS)
private struct MacMapRightClickMonitor: NSViewRepresentable {
    let onRightClick: (CGPoint) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onRightClick: onRightClick)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = .clear
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.attach(to: nsView)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator {
        private let onRightClick: (CGPoint) -> Void
        private weak var view: NSView?
        private var monitor: Any?

        init(onRightClick: @escaping (CGPoint) -> Void) {
            self.onRightClick = onRightClick
        }

        func attach(to view: NSView) {
            self.view = view

            guard monitor == nil else {
                return
            }

            monitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown]) { [weak self] event in
                guard let self, let view = self.view, let window = view.window, event.window === window else {
                    return event
                }

                let localPoint = view.convert(event.locationInWindow, from: nil)
                guard view.bounds.contains(localPoint) else {
                    return event
                }

                self.onRightClick(localPoint)
                return event
            }
        }

        func detach() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }

            view = nil
        }

        deinit {
            detach()
        }
    }
}
#endif

private struct CurrentLocationMarker: View {
    let isManual: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill((isManual ? Color.orange : Color.accentColor).opacity(0.18))
                .frame(width: 28, height: 28)

            Circle()
                .fill(isManual ? Color.orange : Color.accentColor)
                .frame(width: 14, height: 14)
                .overlay {
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 3)
                }
        }
    }
}

struct MapRouteSummary {
    let distanceMeters: Double
    let expectedTravelTime: TimeInterval?
}

private struct ResolvedPreviewRoute {
    let summary: MapRouteSummary
    let lineKind: MapPreviewRouteLineKind
    let polylineCoordinates: [CLLocationCoordinate2D]
}

struct MapRouteCandidate: Identifiable {
    let id: String
    let place: CanonicalPlace
    let target: MapRouteTargetOption
    let availableTargets: [MapRouteTargetOption]
    let summary: MapRouteSummary
    let lineKind: MapPreviewRouteLineKind
    let polylineCoordinates: [CLLocationCoordinate2D]
    let directDistanceMeters: Double

    static func routePriority(lhs: MapRouteCandidate, rhs: MapRouteCandidate) -> Bool {
        switch (lhs.summary.expectedTravelTime, rhs.summary.expectedTravelTime) {
        case let (left?, right?):
            if left == right {
                return lhs.summary.distanceMeters < rhs.summary.distanceMeters
            }
            return left < right
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            if lhs.summary.distanceMeters == rhs.summary.distanceMeters {
                return lhs.directDistanceMeters < rhs.directDistanceMeters
            }
            return lhs.summary.distanceMeters < rhs.summary.distanceMeters
        }
    }

    func displayTitle(language: AppLanguage) -> String {
        place.displayName(for: language)
    }
}

struct MapRouteTargetOption: Identifiable, Hashable {
    let id: String
    let coordinate: GeoCoordinate
    let pointType: RoutingPointType
    let source: RoutingTargetSource

    var symbolName: String {
        switch pointType {
        case .entrance:
            return "door.left.hand.open"
        case .preferred:
            return "star.fill"
        case .object:
            return "square.fill"
        case .inferred:
            return "sparkles"
        case .userSubmitted:
            return "person.fill.badge.plus"
        }
    }

    func pointTitle(language: AppLanguage) -> String {
        L10n.string(pointType.localizationKey, language: language)
    }
}

enum MapPreviewRouteLineKind: Equatable {
    case turnByTurn
    case estimatedStraightLine
}

enum MapPreviewNavigationPhase: Equatable {
    case selection
    case activeNavigation
    case arrived
}

struct MapPreviewNavigationStateResolver {
    static func visibleCandidates(
        sortedCandidates: [MapRouteCandidate],
        activeRouteCandidateID: String?,
        limit: Int = 3
    ) -> [MapRouteCandidate] {
        guard let activeRouteCandidateID else {
            return Array(sortedCandidates.prefix(limit))
        }

        guard let activeCandidate = sortedCandidates.first(where: { $0.id == activeRouteCandidateID }) else {
            return Array(sortedCandidates.prefix(limit))
        }

        var visibleCandidates = [activeCandidate]
        visibleCandidates.append(
            contentsOf: sortedCandidates
                .filter { $0.id != activeRouteCandidateID }
                .prefix(max(limit - 1, 0))
        )
        return visibleCandidates
    }

    static func nextActiveRouteCandidateID(
        currentActiveRouteCandidateID: String?,
        visibleCandidates: [MapRouteCandidate],
        preserveCurrentSelection: Bool
    ) -> String? {
        if preserveCurrentSelection,
           let currentActiveRouteCandidateID,
           visibleCandidates.contains(where: { $0.id == currentActiveRouteCandidateID }) {
            return currentActiveRouteCandidateID
        }

        return visibleCandidates.first?.id
    }

    static func phase(
        remainingDistanceMeters: Double?,
        arrivalThresholdMeters: Double
    ) -> MapPreviewNavigationPhase {
        guard let remainingDistanceMeters else {
            return .activeNavigation
        }

        return remainingDistanceMeters <= arrivalThresholdMeters ? .arrived : .activeNavigation
    }

    static func routeClusterWarning(
        localCity: String?,
        localCandidateCount: Int,
        requestedCandidateCount: Int,
        language: AppLanguage
    ) -> String? {
        guard
            let localCity,
            localCandidateCount > 0,
            localCandidateCount < requestedCandidateCount
        else {
            return nil
        }

        switch language {
        case .russian:
            return "В \(localCity) найдено только \(localCandidateCount) укрытие(я). Остальные альтернативы показаны из соседних городов."
        case .hebrew:
            return "נמצאו רק \(localCandidateCount) מקלטים ב-\(localCity). שאר החלופות מוצגות מערים סמוכות."
        case .english:
            return "Only \(localCandidateCount) shelter option(s) were found in \(localCity). Remaining alternatives are shown from nearby cities."
        }
    }
}

enum MapPreviewTravelMode: String, CaseIterable, Identifiable {
    case walking
    case driving

    var id: Self { self }

    var localizationKey: L10n.Key {
        switch self {
        case .walking:
            return .mapPreviewTransportWalking
        case .driving:
            return .mapPreviewTransportDriving
        }
    }

    var transportType: MKDirectionsTransportType {
        switch self {
        case .walking:
            return .walking
        case .driving:
            return .automobile
        }
    }
}

private func navigationStatusText(for phase: MapPreviewNavigationPhase, language: AppLanguage) -> String {
    switch (language, phase) {
    case (.russian, .selection):
        return "Выберите маршрут"
    case (.russian, .activeNavigation):
        return "Ведем по этому маршруту"
    case (.russian, .arrived):
        return "Вы прибыли"
    case (.hebrew, .selection):
        return "בחר מסלול"
    case (.hebrew, .activeNavigation):
        return "מנווטים במסלול הזה"
    case (.hebrew, .arrived):
        return "הגעת ליעד"
    default:
        switch phase {
        case .selection:
            return "Choose route"
        case .activeNavigation:
            return "Navigating this route"
        case .arrived:
            return "Arrived"
        }
    }
}

private func startNavigationText(language: AppLanguage) -> String {
    switch language {
    case .russian:
        return "Начать"
    case .hebrew:
        return "התחל"
    default:
        return "Start"
    }
}

private func stopNavigationText(language: AppLanguage) -> String {
    switch language {
    case .russian:
        return "Стоп"
    case .hebrew:
        return "עצור"
    default:
        return "Stop"
    }
}

private extension GeoCoordinate {
    var locationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private extension MKPolyline {
    var coordinates: [CLLocationCoordinate2D] {
        var coordinates = Array(
            repeating: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            count: pointCount
        )
        getCoordinates(&coordinates, range: NSRange(location: 0, length: pointCount))
        return coordinates
    }
}

private extension MKCoordinateRegion {
    static func fitting(_ coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)

        let minLatitude = latitudes.min() ?? 0
        let maxLatitude = latitudes.max() ?? 0
        let minLongitude = longitudes.min() ?? 0
        let maxLongitude = longitudes.max() ?? 0

        let center = CLLocationCoordinate2D(
            latitude: (minLatitude + maxLatitude) / 2,
            longitude: (minLongitude + maxLongitude) / 2
        )

        let latitudeDelta = max((maxLatitude - minLatitude) * 1.45, 0.01)
        let longitudeDelta = max((maxLongitude - minLongitude) * 1.45, 0.01)

        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(
                latitudeDelta: latitudeDelta,
                longitudeDelta: longitudeDelta
            )
        )
    }
}

private extension TimeInterval {
    func formattedRouteDuration() -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = self >= 3600 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        return formatter.string(from: self) ?? ""
    }
}
