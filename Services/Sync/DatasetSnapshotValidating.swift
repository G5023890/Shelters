import Foundation
import SQLite3

protocol DatasetSnapshotValidating: Sendable {
    func validateSnapshot(
        at databaseURL: URL,
        metadata: DatasetVersionInfo,
        supportedSchemaVersion: Int,
        currentClientVersion: String
    ) throws
}

struct SQLiteDatasetSnapshotValidator: DatasetSnapshotValidating {
    private let requiredTables: [String]

    init(
        requiredTables: [String] = [
            "schema_migrations",
            "canonical_places",
            "routing_points",
            "user_reports",
            "photo_evidence",
            "sync_metadata",
            "app_settings",
            "pending_uploads"
        ]
    ) {
        self.requiredTables = requiredTables
    }

    func validateSnapshot(
        at databaseURL: URL,
        metadata: DatasetVersionInfo,
        supportedSchemaVersion: Int,
        currentClientVersion: String
    ) throws {
        guard metadata.schemaVersion == supportedSchemaVersion else {
            throw SyncExecutionError.unsupportedSchemaVersion(
                expected: supportedSchemaVersion,
                received: metadata.schemaVersion
            )
        }

        if let minimumClientVersion = metadata.minimumClientVersion,
           !ClientVersionComparator.isSupported(current: currentClientVersion, minimumRequired: minimumClientVersion) {
            throw SyncExecutionError.unsupportedMinimumClientVersion(
                required: minimumClientVersion,
                current: currentClientVersion
            )
        }

        let connection = try ReadOnlySQLiteConnection(path: databaseURL.path)
        defer { connection.close() }

        let tables = try connection.tableNames()
        let missingTables = requiredTables.filter { !tables.contains($0) }

        guard missingTables.isEmpty else {
            throw SyncExecutionError.downloadedSnapshotMissingRequiredTables(missingTables)
        }

        let receivedSchemaVersion = try connection.currentSchemaVersion()
        guard receivedSchemaVersion == metadata.schemaVersion else {
            throw SyncExecutionError.downloadedSnapshotSchemaVersionMismatch(
                expected: metadata.schemaVersion,
                received: receivedSchemaVersion
            )
        }
    }
}

private final class ReadOnlySQLiteConnection {
    private var handle: OpaquePointer?

    init(path: String) throws {
        var rawHandle: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX

        guard sqlite3_open_v2(path, &rawHandle, flags, nil) == SQLITE_OK, let rawHandle else {
            let message = rawHandle.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown error"
            throw SQLiteError.openDatabase(path: path, message: message)
        }

        self.handle = rawHandle
    }

    func close() {
        if let handle {
            sqlite3_close_v2(handle)
            self.handle = nil
        }
    }

    func tableNames() throws -> Set<String> {
        try queryStrings(
            """
            SELECT name
            FROM sqlite_master
            WHERE type = 'table'
            ORDER BY name ASC;
            """
        )
    }

    func currentSchemaVersion() throws -> Int? {
        guard let handle else { return nil }
        let sql = "SELECT MAX(version) AS version FROM schema_migrations;"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw SQLiteError.prepare(sql: sql, message: String(cString: sqlite3_errmsg(handle)))
        }

        defer { sqlite3_finalize(statement) }

        if sqlite3_step(statement) == SQLITE_ROW, sqlite3_column_type(statement, 0) != SQLITE_NULL {
            return Int(sqlite3_column_int64(statement, 0))
        }

        return nil
    }

    private func queryStrings(_ sql: String) throws -> Set<String> {
        guard let handle else {
            return []
        }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw SQLiteError.prepare(sql: sql, message: String(cString: sqlite3_errmsg(handle)))
        }

        defer { sqlite3_finalize(statement) }

        var results = Set<String>()

        while sqlite3_step(statement) == SQLITE_ROW {
            if let cString = sqlite3_column_text(statement, 0) {
                results.insert(String(cString: cString))
            }
        }

        return results
    }
}
