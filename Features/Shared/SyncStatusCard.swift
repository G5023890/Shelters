import SwiftUI

struct SyncStatusCard: View {
    let syncStatus: SyncStatusSnapshot
    let diagnostics: AppEnvironmentDiagnostics?
    let onSyncNow: (() -> Void)?

    init(
        syncStatus: SyncStatusSnapshot,
        diagnostics: AppEnvironmentDiagnostics? = nil,
        onSyncNow: (() -> Void)? = nil
    ) {
        self.syncStatus = syncStatus
        self.diagnostics = diagnostics
        self.onSyncNow = onSyncNow
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.text(.syncStatusTitle))
                .font(.headline)
            MetadataRow(
                title: L10n.string(.syncStatusInstalledDatasetVersion),
                value: syncStatus.installedDatasetVersion ?? L10n.string(.settingsNotAvailable)
            )
            MetadataRow(
                title: L10n.string(.syncStatusRemoteDatasetVersion),
                value: syncStatus.remoteDatasetVersion ?? L10n.string(.settingsNotAvailable)
            )
            MetadataRow(
                title: L10n.string(.syncStatusActivityState),
                value: L10n.string(syncStatus.activityState.localizationKey)
            )
            MetadataRow(
                title: L10n.string(.syncStatusUpdateAvailability),
                value: L10n.string(syncStatus.updateAvailability.localizationKey)
            )
            MetadataRow(
                title: L10n.string(.syncStatusLastChecked),
                value: syncStatus.lastCheckedAt.map(DateCoding.string) ?? L10n.string(.settingsNotAvailable)
            )
            MetadataRow(
                title: L10n.string(.settingsLastSync),
                value: syncStatus.lastSuccessfulSyncAt.map(DateCoding.string) ?? L10n.string(.settingsNotAvailable)
            )

            if let diagnostics {
                MetadataRow(
                    title: L10n.string(.settingsDatasetEndpoint),
                    value: diagnostics.metadataURL?.absoluteString ?? L10n.string(.settingsNotAvailable)
                )
            }

            if let lastPreparedAt = syncStatus.lastPreparedAt {
                MetadataRow(
                    title: L10n.string(.syncStatusLastPrepared),
                    value: DateCoding.string(from: lastPreparedAt)
                )
            }

            if let lastErrorMessage = syncStatus.lastErrorMessage {
                Text("\(L10n.string(.syncStatusLastError)): \(lastErrorMessage)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let onSyncNow {
                Button(action: onSyncNow) {
                    Text(L10n.text(.syncStatusSyncNow))
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 4)
    }
}
