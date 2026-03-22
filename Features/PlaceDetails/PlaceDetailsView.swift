import SwiftUI

struct PlaceDetailsView: View {
    @ObservedObject private var settingsStore: SettingsStore
    @StateObject private var viewModel: PlaceDetailsViewModel
    @State private var isShowingReportSheet = false

    private let reportingService: ReportingService
    private let locationService: LocationService
    private let syncService: SyncService

    @Environment(\.openURL) private var openURL

    init(
        placeID: UUID,
        initialPlace: CanonicalPlace?,
        distanceMeters: Double?,
        placeRepository: CanonicalPlaceRepository,
        routingPointRepository: RoutingPointRepository,
        sourceAttributionRepository: SourceAttributionRepository,
        routingService: RoutingService,
        reportingService: ReportingService,
        locationService: LocationService,
        syncService: SyncService,
        settingsStore: SettingsStore
    ) {
        self.reportingService = reportingService
        self.locationService = locationService
        self.syncService = syncService
        self._settingsStore = ObservedObject(wrappedValue: settingsStore)
        self._viewModel = StateObject(
            wrappedValue: PlaceDetailsViewModel(
                placeID: placeID,
                initialPlace: initialPlace,
                distanceMeters: distanceMeters,
                placeRepository: placeRepository,
                routingPointRepository: routingPointRepository,
                sourceAttributionRepository: sourceAttributionRepository,
                routingService: routingService,
                locationService: locationService,
                syncService: syncService,
                languageProvider: { settingsStore.activeLanguage }
            )
        )
    }

    var body: some View {
        Group {
            if let place = viewModel.place, let presentation = viewModel.presentation {
                let routeDestinations = viewModel.routingDestinations(
                    preferredProvider: settingsStore.preferredRoutingProvider
                )
                let preferredRoute = viewModel.preferredRoutingDestination(
                    preferredProvider: settingsStore.preferredRoutingProvider
                )

                List {
                    Section {
                        PlaceDetailsHeaderCard(
                            presentation: presentation,
                            place: place
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    }

                    Section {
                        if let preferredRoute {
                            RouteProviderButton(
                                destination: preferredRoute,
                                action: {
                                    open(preferredRoute)
                                },
                                emphasis: .primary
                            )
                        }

                        if routeDestinations.count > 1 {
                            ForEach(routeDestinations.filter { !$0.isPreferred }) { destination in
                                RouteProviderButton(
                                    destination: destination,
                                    action: {
                                        open(destination)
                                    },
                                    emphasis: .secondary
                                )
                            }
                        }

                        Button {
                            isShowingReportSheet = true
                        } label: {
                            Label {
                                Text(L10n.text(.placeDetailsReportAction))
                            } icon: {
                                Image(systemName: "exclamationmark.bubble")
                            }
                        }
                    } header: {
                        Text(L10n.text(.placeDetailsActionsSection))
                    }

                    Section {
                        MetadataRow(
                            title: L10n.string(.placeDetailsRoutingSource, language: settingsStore.activeLanguage),
                            value: presentation.routingPointSummaryText
                        )
                        MetadataRow(
                            title: L10n.string(.placeDetailsRoutingPointType, language: settingsStore.activeLanguage),
                            value: viewModel.effectiveRoutingTarget.map {
                                L10n.string($0.pointType.localizationKey, language: settingsStore.activeLanguage)
                            }
                                ?? L10n.string(.settingsNotAvailable, language: settingsStore.activeLanguage)
                        )
                        MetadataRow(
                            title: L10n.string(.placeDetailsSelectedCoordinates, language: settingsStore.activeLanguage),
                            value: presentation.routeCoordinateText
                        )
                        MetadataRow(
                            title: L10n.string(.placeDetailsPreferredProvider, language: settingsStore.activeLanguage),
                            value: L10n.string(
                                settingsStore.preferredRoutingProvider.localizationKey,
                                language: settingsStore.activeLanguage
                            )
                        )
                    } header: {
                        Text(L10n.text(.placeDetailsRoutingSection))
                    }

                    Section {
                        MetadataRow(
                            title: L10n.string(.placeDetailsVerificationTitle, language: settingsStore.activeLanguage),
                            value: presentation.verificationText
                        )
                        MetadataRow(
                            title: L10n.string(.placeDetailsStatus, language: settingsStore.activeLanguage),
                            value: presentation.statusText
                        )
                        MetadataRow(
                            title: L10n.string(.placeDetailsEntranceAvailability, language: settingsStore.activeLanguage),
                            value: presentation.entranceAvailabilityText
                        )
                        MetadataRow(
                            title: L10n.string(.placeDetailsRoutingQualityTitle, language: settingsStore.activeLanguage),
                            value: presentation.routingQualityText
                        )

                        if let lastVerifiedText = presentation.lastVerifiedText {
                            MetadataRow(
                                title: L10n.string(.placeDetailsLastVerifiedAt, language: settingsStore.activeLanguage),
                                value: lastVerifiedText
                            )
                        }

                        if let installedDatasetVersionText = presentation.installedDatasetVersionText {
                            MetadataRow(
                                title: L10n.string(.placeDetailsDatasetVersion, language: settingsStore.activeLanguage),
                                value: installedDatasetVersionText
                            )
                        }

                        if let lastSyncText = presentation.lastSyncText {
                            MetadataRow(
                                title: L10n.string(.placeDetailsLastSyncAt, language: settingsStore.activeLanguage),
                                value: lastSyncText
                            )
                        }

                        if let sourceCoverageText = presentation.sourceCoverageText {
                            MetadataRow(
                                title: L10n.string(.placeDetailsSourceCoverage, language: settingsStore.activeLanguage),
                                value: sourceCoverageText
                            )
                        }
                    } header: {
                        Text(L10n.text(.placeDetailsVerificationSection))
                    }

                    Section {
                        MetadataRow(
                            title: L10n.string(.placeDetailsObjectCoordinates, language: settingsStore.activeLanguage),
                            value: place.objectCoordinate.formattedString()
                        )
                        MetadataRow(
                            title: L10n.string(.placeDetailsEntranceCoordinates, language: settingsStore.activeLanguage),
                            value: place.entranceCoordinate?.formattedString()
                                ?? L10n.string(.settingsNotAvailable, language: settingsStore.activeLanguage)
                        )
                    } header: {
                        Text(L10n.text(.placeDetailsCoordinatesSection))
                    }
                }
                .listStyle(.inset)
                .sheet(isPresented: $isShowingReportSheet) {
                    CreateReportView(
                        initialReportType: .wrongLocation,
                        canonicalPlaceID: place.id,
                        placeDisplayName: presentation.title,
                        reportingService: reportingService,
                        locationService: locationService,
                        syncService: syncService,
                        onCreated: { _ in }
                    )
                }
            } else if let errorMessage = viewModel.errorMessage {
                ContentUnavailableView(
                    L10n.string(.placeDetailsMissing, language: settingsStore.activeLanguage),
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else {
                ProgressView()
                    .controlSize(.large)
            }
        }
        .navigationTitle(L10n.text(.placeDetailsTitle))
        .task {
            await viewModel.load()
        }
    }

    private func open(_ destination: RoutingDestination) {
        openURL(destination.primaryURL) { accepted in
            guard !accepted, let fallbackURL = destination.fallbackURL else {
                return
            }

            openURL(fallbackURL)
        }
    }
}

private struct PlaceDetailsHeaderCard: View {
    let presentation: PlaceDetailsPresentation
    let place: CanonicalPlace

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(presentation.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                PlaceDetailsFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                    HeaderBadge(text: presentation.placeTypeText, systemImage: "building.2")

                    if let distanceText = presentation.distanceText {
                        HeaderBadge(text: distanceText, systemImage: "location")
                    }

                    HeaderBadge(text: presentation.statusText, systemImage: "checkmark.seal")
                    HeaderBadge(text: presentation.entranceAvailabilityText, systemImage: "door.left.hand.open")
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                if let addressText = presentation.addressText {
                    Label(addressText, systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }

                if let cityText = presentation.cityText {
                    Label(cityText, systemImage: "building.columns")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
    }
}

private struct HeaderBadge: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.secondary.opacity(0.12))
            )
    }
}

private struct PlaceDetailsFlowLayout: Layout {
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += rowHeight + verticalSpacing
                rowHeight = 0
            }

            currentX += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: maxWidth, height: currentY + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += rowHeight + verticalSpacing
                rowHeight = 0
            }

            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            currentX += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
