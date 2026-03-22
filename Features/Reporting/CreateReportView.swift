import SwiftUI

struct CreateReportView: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject private var viewModel: CreateReportViewModel

    private let onCreated: @MainActor (UserReport) async -> Void

    init(
        initialReportType: ReportType,
        canonicalPlaceID: UUID? = nil,
        placeDisplayName: String? = nil,
        reportingService: ReportingService,
        locationService: LocationService,
        syncService: SyncService,
        onCreated: @escaping @MainActor (UserReport) async -> Void
    ) {
        self._viewModel = StateObject(
            wrappedValue: CreateReportViewModel(
                initialReportType: initialReportType,
                canonicalPlaceID: canonicalPlaceID,
                placeDisplayName: placeDisplayName,
                reportingService: reportingService,
                locationService: locationService,
                syncService: syncService
            )
        )
        self.onCreated = onCreated
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let placeDisplayName = viewModel.placeDisplayName {
                        MetadataRow(
                            title: L10n.string(.placeDetailsTitle),
                            value: placeDisplayName
                        )
                    }

                    Picker(
                        selection: $viewModel.selectedReportType,
                        label: Text(L10n.text(.reportingFormType))
                    ) {
                        ForEach(ReportType.allCases) { reportType in
                            Text(L10n.text(reportType.localizationKey))
                                .tag(reportType)
                        }
                    }
                }

                Section(L10n.string(.reportingFormCurrentLocation)) {
                    if let userCoordinate = viewModel.userCoordinate {
                        MetadataRow(
                            title: L10n.string(.reportingUserCoordinates),
                            value: userCoordinate.formattedString()
                        )
                    } else {
                        Text(L10n.text(.reportingNoLocation))
                            .foregroundStyle(.secondary)
                    }

                    if viewModel.isResolvingLocation {
                        ProgressView()
                    }

                    Button(L10n.text(.reportingFormUseCurrentLocation)) {
                        Task {
                            await viewModel.captureCurrentLocation()
                        }
                    }

                    if viewModel.userCoordinate != nil {
                        Button(L10n.text(.reportingFormClearLocation)) {
                            viewModel.clearCurrentLocation()
                        }
                    }

                    Toggle(
                        isOn: $viewModel.useCurrentLocationAsSuggestedEntrance,
                        label: {
                            Text(L10n.text(.reportingFormUseCurrentLocationForEntrance))
                        }
                    )

                    if let suggestedEntrance = viewModel.suggestedEntranceCoordinate {
                        MetadataRow(
                            title: L10n.string(.reportingSuggestedEntrance),
                            value: suggestedEntrance.formattedString()
                        )
                    }
                }

                Section(L10n.string(.reportingNote)) {
                    ZStack(alignment: .topLeading) {
                        if viewModel.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(L10n.text(.reportingFormNotePlaceholder))
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.horizontal, 6)
                        }

                        TextEditor(text: $viewModel.note)
                            .frame(minHeight: 120)
                    }
                }

                Section(L10n.string(.reportingFormDatasetVersion)) {
                    MetadataRow(
                        title: L10n.string(.reportingDatasetVersion),
                        value: viewModel.datasetVersionDisplay
                    )
                }
            }
            .navigationTitle(L10n.string(.reportingCreateButton))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.text(.commonCancel)) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text(.reportingFormSave)) {
                        Task {
                            await saveReport()
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
            .task {
                await viewModel.load()
            }
            .alert(
                L10n.string(.commonClose),
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { isPresented in
                        if !isPresented {
                            viewModel.errorMessage = nil
                        }
                    }
                ),
                actions: {
                    Button(L10n.text(.commonDone), role: .cancel) {
                        viewModel.errorMessage = nil
                    }
                },
                message: {
                    Text(viewModel.errorMessage ?? "")
                }
            )
        }
    }

    private func saveReport() async {
        guard let report = await viewModel.save() else {
            return
        }

        await onCreated(report)
        dismiss()
    }
}

@MainActor
final class CreateReportViewModel: ObservableObject {
    @Published var selectedReportType: ReportType
    @Published var note = ""
    @Published private(set) var datasetVersion = ReportingConstants.unavailableDatasetVersion
    @Published private(set) var placeDisplayName: String?
    @Published private(set) var userCoordinate: GeoCoordinate?
    @Published var useCurrentLocationAsSuggestedEntrance = false
    @Published private(set) var isResolvingLocation = false
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?

    private let reportingService: ReportingService
    private let locationService: LocationService
    private let syncService: SyncService
    private let canonicalPlaceID: UUID?

    init(
        initialReportType: ReportType,
        canonicalPlaceID: UUID?,
        placeDisplayName: String?,
        reportingService: ReportingService,
        locationService: LocationService,
        syncService: SyncService
    ) {
        self.selectedReportType = initialReportType
        self.canonicalPlaceID = canonicalPlaceID
        self.placeDisplayName = placeDisplayName
        self.reportingService = reportingService
        self.locationService = locationService
        self.syncService = syncService
    }

    var suggestedEntranceCoordinate: GeoCoordinate? {
        guard useCurrentLocationAsSuggestedEntrance else {
            return nil
        }

        return userCoordinate
    }

    var datasetVersionDisplay: String {
        datasetVersion == ReportingConstants.unavailableDatasetVersion ? L10n.string(.settingsNotAvailable) : datasetVersion
    }

    func load() async {
        let syncStatus = await syncService.fetchSyncStatus()
        datasetVersion = syncStatus.installedDatasetVersion ?? ReportingConstants.unavailableDatasetVersion
    }

    func captureCurrentLocation() async {
        isResolvingLocation = true
        defer { isResolvingLocation = false }

        do {
            userCoordinate = try await locationService.currentLocation()?.coordinate

            if userCoordinate == nil {
                errorMessage = L10n.string(.reportingNoLocation)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearCurrentLocation() {
        userCoordinate = nil
        useCurrentLocationAsSuggestedEntrance = false
    }

    func save() async -> UserReport? {
        isSaving = true
        defer { isSaving = false }

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let draft = UserReportDraft(
            canonicalPlaceID: canonicalPlaceID,
            reportType: selectedReportType,
            userCoordinate: userCoordinate,
            suggestedEntranceCoordinate: suggestedEntranceCoordinate,
            textNote: trimmedNote.isEmpty ? nil : trimmedNote,
            datasetVersion: datasetVersion
        )

        do {
            let report = try await reportingService.createPendingReport(from: draft)
            errorMessage = nil
            return report
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
