import Foundation

enum SyncExecutionError: LocalizedError, Equatable {
    case metadataEndpointNotConfigured
    case metadataDecodingFailed
    case unsupportedSchemaVersion(expected: Int, received: Int)
    case unsupportedMinimumClientVersion(required: String, current: String)
    case downloadedSnapshotMissingRequiredTables([String])
    case downloadedSnapshotSchemaVersionMismatch(expected: Int, received: Int?)
    case failedToMergeLocalState
    case syncMetadataPersistenceFailed

    var errorDescription: String? {
        switch self {
        case .metadataEndpointNotConfigured:
            return "Dataset metadata endpoint is not configured."
        case .metadataDecodingFailed:
            return "Dataset metadata could not be decoded."
        case .unsupportedSchemaVersion(let expected, let received):
            return "Dataset schema version \(received) is not compatible with client schema version \(expected)."
        case .unsupportedMinimumClientVersion(let required, let current):
            return "Dataset requires client version \(required), but the app is running version \(current)."
        case .downloadedSnapshotMissingRequiredTables(let tables):
            return "Downloaded dataset is missing required tables: \(tables.joined(separator: ", "))."
        case .downloadedSnapshotSchemaVersionMismatch(let expected, let received):
            let receivedDescription = received.map(String.init) ?? "none"
            return "Downloaded dataset schema migration version \(receivedDescription) does not match expected version \(expected)."
        case .failedToMergeLocalState:
            return "Local user state could not be merged into the downloaded dataset snapshot."
        case .syncMetadataPersistenceFailed:
            return "Sync metadata could not be persisted."
        }
    }
}
