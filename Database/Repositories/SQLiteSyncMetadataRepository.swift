import Foundation

final class SQLiteSyncMetadataRepository: SyncMetadataRepository {
    private let database: SQLiteDatabase

    init(database: SQLiteDatabase) {
        self.database = database
    }

    func value(for key: String) throws -> String? {
        try database.query(
            "SELECT value FROM sync_metadata WHERE key = ? LIMIT 1;",
            bindings: [.text(key)]
        )
        .first?
        .string("value")
    }

    func setValue(_ value: String, for key: String) throws {
        try database.execute(
            """
            INSERT INTO sync_metadata (key, value)
            VALUES (?, ?)
            ON CONFLICT(key) DO UPDATE SET value = excluded.value;
            """,
            bindings: [.text(key), .text(value)]
        )
    }

    func fetchAll() throws -> [SyncMetadata] {
        try database.query("SELECT key, value FROM sync_metadata ORDER BY key ASC;")
            .compactMap { row in
                guard let key = row.string("key"), let value = row.string("value") else {
                    return nil
                }

                return SyncMetadata(key: key, value: value)
            }
    }
}

