import Foundation

protocol SyncService: Sendable {
    func fetchSyncStatus() async -> SyncStatusSnapshot
    func synchronizeNow() async -> SyncOperationResult
}
