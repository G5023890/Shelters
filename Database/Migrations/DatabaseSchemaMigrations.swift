import Foundation

enum DatabaseSchemaMigrations {
    static var latestVersion: Int {
        all.map(\.version).max() ?? 0
    }

    static let all: [DatabaseMigration] = [
        DatabaseMigration(
            version: 1,
            name: "initial_foundation",
            statements: [
                """
                CREATE TABLE IF NOT EXISTS canonical_places (
                    id TEXT PRIMARY KEY NOT NULL,
                    name_original TEXT,
                    name_en TEXT,
                    name_ru TEXT,
                    name_he TEXT,
                    address_original TEXT,
                    address_en TEXT,
                    address_ru TEXT,
                    address_he TEXT,
                    city TEXT,
                    place_type TEXT NOT NULL,
                    object_lat REAL NOT NULL,
                    object_lon REAL NOT NULL,
                    entrance_lat REAL,
                    entrance_lon REAL,
                    preferred_routing_lat REAL NOT NULL,
                    preferred_routing_lon REAL NOT NULL,
                    preferred_routing_point_type TEXT,
                    search_tile_key TEXT,
                    is_public INTEGER NOT NULL DEFAULT 1,
                    is_accessible INTEGER NOT NULL DEFAULT 0,
                    status TEXT NOT NULL,
                    confidence_score REAL NOT NULL DEFAULT 0,
                    routing_quality REAL NOT NULL DEFAULT 0,
                    last_verified_at TEXT,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                );
                """,
                """
                CREATE TABLE IF NOT EXISTS routing_points (
                    id TEXT PRIMARY KEY NOT NULL,
                    canonical_place_id TEXT NOT NULL,
                    lat REAL NOT NULL,
                    lon REAL NOT NULL,
                    point_type TEXT NOT NULL,
                    confidence REAL NOT NULL DEFAULT 0,
                    derived_from TEXT,
                    created_at TEXT NOT NULL,
                    FOREIGN KEY (canonical_place_id) REFERENCES canonical_places(id) ON DELETE CASCADE
                );
                """,
                """
                CREATE TABLE IF NOT EXISTS user_reports (
                    id TEXT PRIMARY KEY NOT NULL,
                    canonical_place_id TEXT,
                    report_type TEXT NOT NULL,
                    report_status TEXT NOT NULL,
                    user_lat REAL,
                    user_lon REAL,
                    suggested_entrance_lat REAL,
                    suggested_entrance_lon REAL,
                    text_note TEXT,
                    dataset_version TEXT NOT NULL,
                    local_created_at TEXT NOT NULL,
                    uploaded_at TEXT,
                    FOREIGN KEY (canonical_place_id) REFERENCES canonical_places(id) ON DELETE SET NULL
                );
                """,
                """
                CREATE TABLE IF NOT EXISTS photo_evidence (
                    id TEXT PRIMARY KEY NOT NULL,
                    report_id TEXT NOT NULL,
                    local_file_path TEXT NOT NULL,
                    exif_lat REAL,
                    exif_lon REAL,
                    captured_at TEXT,
                    has_metadata INTEGER NOT NULL DEFAULT 0,
                    checksum TEXT,
                    FOREIGN KEY (report_id) REFERENCES user_reports(id) ON DELETE CASCADE
                );
                """,
                """
                CREATE TABLE IF NOT EXISTS sync_metadata (
                    key TEXT PRIMARY KEY NOT NULL,
                    value TEXT NOT NULL
                );
                """,
                """
                CREATE TABLE IF NOT EXISTS app_settings (
                    key TEXT PRIMARY KEY NOT NULL,
                    value TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                );
                """,
                """
                CREATE TABLE IF NOT EXISTS pending_uploads (
                    id TEXT PRIMARY KEY NOT NULL,
                    entity_type TEXT NOT NULL,
                    entity_id TEXT NOT NULL,
                    upload_state TEXT NOT NULL,
                    last_error TEXT,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                );
                """,
                """
                CREATE TABLE IF NOT EXISTS place_history (
                    id TEXT PRIMARY KEY NOT NULL,
                    canonical_place_id TEXT NOT NULL,
                    change_summary TEXT NOT NULL,
                    changed_at TEXT NOT NULL,
                    FOREIGN KEY (canonical_place_id) REFERENCES canonical_places(id) ON DELETE CASCADE
                );
                """,
                """
                CREATE TABLE IF NOT EXISTS source_attribution (
                    id TEXT PRIMARY KEY NOT NULL,
                    canonical_place_id TEXT NOT NULL,
                    source_name TEXT NOT NULL,
                    source_identifier TEXT,
                    imported_at TEXT NOT NULL,
                    FOREIGN KEY (canonical_place_id) REFERENCES canonical_places(id) ON DELETE CASCADE
                );
                """,
                "CREATE INDEX IF NOT EXISTS idx_canonical_places_place_type ON canonical_places(place_type);",
                "CREATE INDEX IF NOT EXISTS idx_canonical_places_status ON canonical_places(status);",
                "CREATE INDEX IF NOT EXISTS idx_canonical_places_updated_at ON canonical_places(updated_at);",
                "CREATE INDEX IF NOT EXISTS idx_canonical_places_search_tile_key ON canonical_places(search_tile_key);",
                "CREATE INDEX IF NOT EXISTS idx_canonical_places_preferred_routing_coords ON canonical_places(preferred_routing_lat, preferred_routing_lon);",
                "CREATE INDEX IF NOT EXISTS idx_canonical_places_object_coords ON canonical_places(object_lat, object_lon);",
                "CREATE INDEX IF NOT EXISTS idx_canonical_places_entrance_coords ON canonical_places(entrance_lat, entrance_lon);",
                "CREATE INDEX IF NOT EXISTS idx_routing_points_place_id ON routing_points(canonical_place_id);",
                "CREATE INDEX IF NOT EXISTS idx_routing_points_type ON routing_points(point_type);",
                "CREATE INDEX IF NOT EXISTS idx_user_reports_place_id ON user_reports(canonical_place_id);",
                "CREATE INDEX IF NOT EXISTS idx_user_reports_status ON user_reports(report_status);",
                "CREATE INDEX IF NOT EXISTS idx_photo_evidence_report_id ON photo_evidence(report_id);",
                "CREATE INDEX IF NOT EXISTS idx_pending_uploads_state ON pending_uploads(upload_state);",
                "CREATE INDEX IF NOT EXISTS idx_place_history_place_id ON place_history(canonical_place_id);",
                "CREATE INDEX IF NOT EXISTS idx_source_attribution_place_id ON source_attribution(canonical_place_id);"
            ]
        ),
        DatabaseMigration(
            version: 2,
            name: "reporting_upload_lifecycle",
            statements: [
                "ALTER TABLE user_reports ADD COLUMN status_updated_at TEXT NOT NULL DEFAULT '1970-01-01T00:00:00Z';",
                "ALTER TABLE user_reports ADD COLUMN upload_attempt_count INTEGER NOT NULL DEFAULT 0;",
                "ALTER TABLE user_reports ADD COLUMN last_upload_attempt_at TEXT;",
                "ALTER TABLE user_reports ADD COLUMN last_error TEXT;",
                "ALTER TABLE photo_evidence ADD COLUMN created_at TEXT NOT NULL DEFAULT '1970-01-01T00:00:00Z';",
                "ALTER TABLE pending_uploads ADD COLUMN report_id TEXT;",
                "ALTER TABLE pending_uploads ADD COLUMN attempt_count INTEGER NOT NULL DEFAULT 0;",
                "ALTER TABLE pending_uploads ADD COLUMN last_attempt_at TEXT;",
                "ALTER TABLE pending_uploads ADD COLUMN completed_at TEXT;",
                """
                UPDATE user_reports
                SET
                    status_updated_at = COALESCE(uploaded_at, local_created_at),
                    upload_attempt_count = CASE
                        WHEN report_status = 'uploaded' THEN 1
                        ELSE 0
                    END,
                    last_upload_attempt_at = uploaded_at,
                    last_error = NULL;
                """,
                """
                UPDATE photo_evidence
                SET created_at = COALESCE(captured_at, '1970-01-01T00:00:00Z');
                """,
                """
                UPDATE pending_uploads
                SET
                    report_id = CASE
                        WHEN entity_type = 'user_report' THEN entity_id
                        ELSE (
                            SELECT report_id
                            FROM photo_evidence
                            WHERE photo_evidence.id = pending_uploads.entity_id
                        )
                    END,
                    attempt_count = CASE
                        WHEN upload_state = 'uploaded' THEN 1
                        ELSE 0
                    END,
                    last_attempt_at = CASE
                        WHEN upload_state = 'uploaded' THEN updated_at
                        ELSE NULL
                    END,
                    completed_at = CASE
                        WHEN upload_state = 'uploaded' THEN updated_at
                        ELSE NULL
                    END,
                    upload_state = CASE
                        WHEN upload_state = 'queued' THEN 'pending_upload'
                        ELSE upload_state
                    END;
                """,
                """
                UPDATE user_reports
                SET report_status = CASE
                    WHEN report_status = 'queued' THEN 'pending_upload'
                    WHEN report_status = 'needs_review' THEN 'failed'
                    ELSE report_status
                END;
                """,
                "CREATE INDEX IF NOT EXISTS idx_user_reports_created_at ON user_reports(local_created_at);",
                "CREATE INDEX IF NOT EXISTS idx_pending_uploads_report_id ON pending_uploads(report_id);"
            ]
        )
    ]
}
