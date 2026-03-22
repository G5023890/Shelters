import Foundation

protocol LocalDatabaseStatePreserving: Sendable {
    func mergeLocalState(from liveDatabaseURL: URL, into stagedDatabaseURL: URL) throws
}

struct SQLiteLocalDatabaseStatePreserver: LocalDatabaseStatePreserving {
    private let preservedTables: [String]

    init(
        preservedTables: [String] = [
            "app_settings",
            "sync_metadata",
            "user_reports",
            "photo_evidence",
            "pending_uploads"
        ]
    ) {
        self.preservedTables = preservedTables
    }

    func mergeLocalState(from liveDatabaseURL: URL, into stagedDatabaseURL: URL) throws {
        guard FileManager.default.fileExists(atPath: liveDatabaseURL.path) else {
            return
        }

        do {
            let stagedDatabase = try SQLiteDatabase(path: stagedDatabaseURL.path)
            let escapedLivePath = liveDatabaseURL.path.replacingOccurrences(of: "'", with: "''")

            try stagedDatabase.transaction { connection in
                try connection.execute("ATTACH DATABASE '\(escapedLivePath)' AS live_state;")
                defer { try? connection.execute("DETACH DATABASE live_state;") }

                for table in preservedTables {
                    try connection.execute("DELETE FROM \(table);")
                    try connection.execute("INSERT INTO \(table) SELECT * FROM live_state.\(table);")
                }
            }
        } catch {
            throw SyncExecutionError.failedToMergeLocalState
        }
    }
}
