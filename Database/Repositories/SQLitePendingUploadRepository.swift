import Foundation

final class SQLitePendingUploadRepository: PendingUploadRepository {
    private let database: SQLiteDatabase

    init(database: SQLiteDatabase) {
        self.database = database
    }

    func save(_ item: PendingUploadItem) throws {
        try database.execute(
            """
            INSERT INTO pending_uploads (
                id,
                entity_type,
                entity_id,
                report_id,
                upload_state,
                last_error,
                attempt_count,
                last_attempt_at,
                completed_at,
                created_at,
                updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                entity_type = excluded.entity_type,
                entity_id = excluded.entity_id,
                report_id = excluded.report_id,
                upload_state = excluded.upload_state,
                last_error = excluded.last_error,
                attempt_count = excluded.attempt_count,
                last_attempt_at = excluded.last_attempt_at,
                completed_at = excluded.completed_at,
                created_at = excluded.created_at,
                updated_at = excluded.updated_at;
            """,
            bindings: [
                .text(item.id.uuidString),
                .text(item.entityType.rawValue),
                .text(item.entityID),
                .text(item.reportID.uuidString),
                .text(item.uploadState.rawValue),
                textOrNull(item.lastError),
                .integer(Int64(item.attemptCount)),
                textOrNull(item.lastAttemptAt.map(DateCoding.string)),
                textOrNull(item.completedAt.map(DateCoding.string)),
                .text(DateCoding.string(from: item.createdAt)),
                .text(DateCoding.string(from: item.updatedAt))
            ]
        )
    }

    func fetchPendingUploads() throws -> [PendingUploadItem] {
        try fetch(
            """
            SELECT *
            FROM pending_uploads
            WHERE upload_state IN (?, ?, ?)
            ORDER BY created_at ASC;
            """,
            bindings: [
                .text(PendingUploadState.pendingUpload.rawValue),
                .text(PendingUploadState.uploading.rawValue),
                .text(PendingUploadState.failed.rawValue)
            ]
        )
    }

    func fetchUploads(for reportID: UUID) throws -> [PendingUploadItem] {
        try fetch(
            """
            SELECT *
            FROM pending_uploads
            WHERE report_id = ?
            ORDER BY created_at ASC;
            """,
            bindings: [.text(reportID.uuidString)]
        )
    }

    func fetch(id: UUID) throws -> PendingUploadItem? {
        try fetch(
            "SELECT * FROM pending_uploads WHERE id = ? LIMIT 1;",
            bindings: [.text(id.uuidString)]
        )
        .first
    }

    func fetch(entityType: PendingUploadEntityType, entityID: String) throws -> PendingUploadItem? {
        try fetch(
            """
            SELECT *
            FROM pending_uploads
            WHERE entity_type = ? AND entity_id = ?
            LIMIT 1;
            """,
            bindings: [
                .text(entityType.rawValue),
                .text(entityID)
            ]
        )
        .first
    }

    private func fetch(_ sql: String, bindings: [SQLiteValue]) throws -> [PendingUploadItem] {
        try database.query(sql, bindings: bindings)
            .compactMap(makeItem(from:))
    }

    private func makeItem(from row: SQLiteRow) -> PendingUploadItem? {
        guard
            let idString = row.string("id"),
            let id = UUID(uuidString: idString),
            let entityTypeRaw = row.string("entity_type"),
            let entityType = PendingUploadEntityType(rawValue: entityTypeRaw),
            let entityID = row.string("entity_id"),
            let reportIDString = row.string("report_id"),
            let reportID = UUID(uuidString: reportIDString),
            let uploadStateRaw = row.string("upload_state"),
            let uploadState = PendingUploadState(rawValue: uploadStateRaw),
            let createdAtString = row.string("created_at"),
            let createdAt = DateCoding.date(from: createdAtString),
            let updatedAtString = row.string("updated_at"),
            let updatedAt = DateCoding.date(from: updatedAtString)
        else {
            return nil
        }

        return PendingUploadItem(
            id: id,
            entityType: entityType,
            entityID: entityID,
            reportID: reportID,
            uploadState: uploadState,
            lastError: row.string("last_error"),
            attemptCount: row.int64("attempt_count").map(Int.init) ?? 0,
            lastAttemptAt: row.string("last_attempt_at").flatMap(DateCoding.date),
            completedAt: row.string("completed_at").flatMap(DateCoding.date),
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
