import Foundation

struct SyncOperationResult: Sendable {
    let snapshot: SyncStatusSnapshot
    let remoteVersionInfo: DatasetVersionInfo?
    let didInstallUpdate: Bool
}
