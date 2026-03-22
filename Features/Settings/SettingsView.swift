import SwiftUI

extension Notification.Name {
    static let sheltersDatasetDidSync = Notification.Name("sheltersDatasetDidSync")
}

struct SettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    @StateObject private var viewModel: SettingsViewModel
    private let diagnostics: AppEnvironmentDiagnostics

    init(
        syncService: SyncService,
        settingsStore: SettingsStore,
        diagnostics: AppEnvironmentDiagnostics
    ) {
        self._settingsStore = ObservedObject(wrappedValue: settingsStore)
        self.diagnostics = diagnostics
        self._viewModel = StateObject(wrappedValue: SettingsViewModel(syncService: syncService))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker(
                        selection: Binding(
                            get: { settingsStore.preferredRoutingProvider },
                            set: { settingsStore.updatePreferredRoutingProvider($0) }
                        ),
                        label: Text(L10n.text(.settingsPreferredRoutingProvider))
                    ) {
                        ForEach(RoutingAppProvider.allCases) { provider in
                            Text(L10n.text(provider.localizationKey))
                                .tag(provider)
                        }
                    }
                } header: {
                    Text(L10n.text(.settingsRoutingSection))
                } footer: {
                    Text(L10n.text(.settingsRoutingHint))
                }

                Section(L10n.string(.settingsLanguageSection)) {
                    Picker(
                        selection: Binding<String>(
                            get: { settingsStore.languageOverride?.rawValue ?? "" },
                            set: { newValue in
                                settingsStore.updateLanguageOverride(AppLanguage(rawValue: newValue))
                            }
                        ),
                        label: Text(L10n.text(.settingsLanguageOverride))
                    ) {
                        Text(L10n.text(.settingsSystemDefault))
                            .tag("")
                        ForEach(AppLanguage.allCases) { language in
                            Text(L10n.text(language.settingsLocalizationKey))
                                .tag(language.rawValue)
                            }
                    }
                }

                Section(L10n.string(.settingsSyncSection)) {
                    SyncStatusCard(
                        syncStatus: viewModel.syncStatus,
                        diagnostics: diagnostics,
                        onSyncNow: {
                            Task {
                                await viewModel.synchronizeNow()
                            }
                        }
                    )
                }

                Section(L10n.string(.settingsEnvironmentSection)) {
                    MetadataRow(
                        title: L10n.string(.settingsEnvironmentName),
                        value: diagnostics.environmentName
                    )
                    MetadataRow(
                        title: L10n.string(.settingsDatasetSource),
                        value: diagnostics.datasetSourceName
                    )
                    MetadataRow(
                        title: L10n.string(.settingsDatasetEndpoint),
                        value: diagnostics.metadataURL?.absoluteString ?? L10n.string(.settingsNotAvailable)
                    )
                    MetadataRow(
                        title: L10n.string(.settingsReportingSource),
                        value: diagnostics.reportingSourceName
                    )
                    MetadataRow(
                        title: L10n.string(.settingsReportsEndpoint),
                        value: diagnostics.reportsURL?.absoluteString ?? L10n.string(.settingsNotAvailable)
                    )
                    MetadataRow(
                        title: L10n.string(.settingsReportPhotosEndpoint),
                        value: diagnostics.reportPhotosURL?.absoluteString ?? L10n.string(.settingsNotAvailable)
                    )
                }
            }
            .navigationTitle(L10n.string(.settingsTitle))
        }
        .task {
            await viewModel.load()
        }
    }
}

@MainActor
private final class SettingsViewModel: ObservableObject {
    @Published private(set) var syncStatus = SyncStatusSnapshot.initial

    private let syncService: SyncService

    init(syncService: SyncService) {
        self.syncService = syncService
    }

    func load() async {
        syncStatus = await syncService.fetchSyncStatus()
    }

    func synchronizeNow() async {
        let result = await syncService.synchronizeNow()
        syncStatus = result.snapshot

        guard result.didInstallUpdate else {
            return
        }

        NotificationCenter.default.post(name: .sheltersDatasetDidSync, object: nil)
    }
}
