import Foundation

struct DatabaseMigrator {
    private let migrations: [DatabaseMigration]

    init(migrations: [DatabaseMigration] = DatabaseSchemaMigrations.all) {
        self.migrations = migrations.sorted { $0.version < $1.version }
    }

    func migrate(_ database: SQLiteDatabase) throws {
        try database.execute("""
        CREATE TABLE IF NOT EXISTS schema_migrations (
            version INTEGER PRIMARY KEY NOT NULL,
            name TEXT NOT NULL,
            applied_at TEXT NOT NULL
        );
        """)

        let appliedVersions = try Set(
            database.query("SELECT version FROM schema_migrations")
                .compactMap { $0.int64("version").map(Int.init) }
        )

        for migration in migrations where !appliedVersions.contains(migration.version) {
            try database.transaction { connection in
                for statement in migration.statements {
                    try connection.execute(statement)
                }

                try connection.execute(
                    """
                    INSERT INTO schema_migrations (version, name, applied_at)
                    VALUES (?, ?, ?);
                    """,
                    bindings: [
                        .integer(Int64(migration.version)),
                        .text(migration.name),
                        .text(DateCoding.string(from: Date()))
                    ]
                )
            }
        }
    }
}

