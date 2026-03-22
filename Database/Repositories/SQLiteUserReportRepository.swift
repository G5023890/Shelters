import Foundation

final class SQLiteUserReportRepository: UserReportRepository {
    private let database: SQLiteDatabase

    init(database: SQLiteDatabase) {
        self.database = database
    }

    func save(_ report: UserReport) throws {
        try database.execute(
            """
            INSERT INTO user_reports (
                id,
                canonical_place_id,
                report_type,
                report_status,
                user_lat,
                user_lon,
                suggested_entrance_lat,
                suggested_entrance_lon,
                text_note,
                dataset_version,
                local_created_at,
                status_updated_at,
                upload_attempt_count,
                last_upload_attempt_at,
                last_error,
                uploaded_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                canonical_place_id = excluded.canonical_place_id,
                report_type = excluded.report_type,
                report_status = excluded.report_status,
                user_lat = excluded.user_lat,
                user_lon = excluded.user_lon,
                suggested_entrance_lat = excluded.suggested_entrance_lat,
                suggested_entrance_lon = excluded.suggested_entrance_lon,
                text_note = excluded.text_note,
                dataset_version = excluded.dataset_version,
                local_created_at = excluded.local_created_at,
                status_updated_at = excluded.status_updated_at,
                upload_attempt_count = excluded.upload_attempt_count,
                last_upload_attempt_at = excluded.last_upload_attempt_at,
                last_error = excluded.last_error,
                uploaded_at = excluded.uploaded_at;
            """,
            bindings: [
                .text(report.id.uuidString),
                textOrNull(report.canonicalPlaceID?.uuidString),
                .text(report.reportType.rawValue),
                .text(report.reportStatus.rawValue),
                doubleOrNull(report.userCoordinate?.latitude),
                doubleOrNull(report.userCoordinate?.longitude),
                doubleOrNull(report.suggestedEntranceCoordinate?.latitude),
                doubleOrNull(report.suggestedEntranceCoordinate?.longitude),
                textOrNull(report.textNote),
                .text(report.datasetVersion),
                .text(DateCoding.string(from: report.localCreatedAt)),
                .text(DateCoding.string(from: report.statusUpdatedAt)),
                .integer(Int64(report.uploadAttemptCount)),
                textOrNull(report.lastUploadAttemptAt.map(DateCoding.string)),
                textOrNull(report.lastError),
                textOrNull(report.uploadedAt.map(DateCoding.string))
            ]
        )
    }

    func fetchPendingReports() throws -> [UserReport] {
        try fetch(
            """
            SELECT *
            FROM user_reports
            WHERE report_status IN (?, ?, ?, ?)
            ORDER BY local_created_at ASC;
            """,
            bindings: [
                .text(ReportStatus.draft.rawValue),
                .text(ReportStatus.pendingUpload.rawValue),
                .text(ReportStatus.uploading.rawValue),
                .text(ReportStatus.failed.rawValue)
            ]
        )
    }

    func fetchAll(limit: Int?) throws -> [UserReport] {
        let limitClause = limit.map { " LIMIT \($0)" } ?? ""
        return try fetch(
            """
            SELECT *
            FROM user_reports
            ORDER BY local_created_at DESC\(limitClause);
            """,
            bindings: []
        )
    }

    func fetch(id: UUID) throws -> UserReport? {
        try fetch(
            "SELECT * FROM user_reports WHERE id = ? LIMIT 1;",
            bindings: [.text(id.uuidString)]
        )
        .first
    }

    private func fetch(_ sql: String, bindings: [SQLiteValue]) throws -> [UserReport] {
        try database.query(sql, bindings: bindings)
            .compactMap(makeReport(from:))
    }

    private func makeReport(from row: SQLiteRow) -> UserReport? {
        guard
            let idString = row.string("id"),
            let id = UUID(uuidString: idString),
            let reportTypeRaw = row.string("report_type"),
            let reportType = ReportType(rawValue: reportTypeRaw),
            let statusRaw = row.string("report_status"),
            let status = ReportStatus(rawValue: statusRaw),
            let createdAtString = row.string("local_created_at"),
            let createdAt = DateCoding.date(from: createdAtString),
            let statusUpdatedAtString = row.string("status_updated_at"),
            let statusUpdatedAt = DateCoding.date(from: statusUpdatedAtString),
            let datasetVersion = row.string("dataset_version")
        else {
            return nil
        }

        let userCoordinate = makeCoordinate(lat: row.double("user_lat"), lon: row.double("user_lon"))
        let entranceCoordinate = makeCoordinate(
            lat: row.double("suggested_entrance_lat"),
            lon: row.double("suggested_entrance_lon")
        )

        return UserReport(
            id: id,
            canonicalPlaceID: row.string("canonical_place_id").flatMap(UUID.init(uuidString:)),
            reportType: reportType,
            reportStatus: status,
            userCoordinate: userCoordinate,
            suggestedEntranceCoordinate: entranceCoordinate,
            textNote: row.string("text_note"),
            datasetVersion: datasetVersion,
            localCreatedAt: createdAt,
            statusUpdatedAt: statusUpdatedAt,
            uploadAttemptCount: row.int64("upload_attempt_count").map(Int.init) ?? 0,
            lastUploadAttemptAt: row.string("last_upload_attempt_at").flatMap(DateCoding.date),
            lastError: row.string("last_error"),
            uploadedAt: row.string("uploaded_at").flatMap(DateCoding.date)
        )
    }
}
