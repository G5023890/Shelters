import Foundation

final class SQLiteAppSettingsRepository: AppSettingsRepository {
    private let database: SQLiteDatabase

    init(database: SQLiteDatabase) {
        self.database = database
    }

    func value(for key: String) throws -> String? {
        try database.query(
            "SELECT value FROM app_settings WHERE key = ? LIMIT 1;",
            bindings: [.text(key)]
        )
        .first?
        .string("value")
    }

    func setValue(_ value: String, for key: String) throws {
        try database.execute(
            """
            INSERT INTO app_settings (key, value, updated_at)
            VALUES (?, ?, ?)
            ON CONFLICT(key) DO UPDATE SET
                value = excluded.value,
                updated_at = excluded.updated_at;
            """,
            bindings: [
                .text(key),
                .text(value),
                .text(DateCoding.string(from: Date()))
            ]
        )
    }
}
