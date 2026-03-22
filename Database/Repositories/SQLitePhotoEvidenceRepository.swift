import Foundation

final class SQLitePhotoEvidenceRepository: PhotoEvidenceRepository {
    private let database: SQLiteDatabase

    init(database: SQLiteDatabase) {
        self.database = database
    }

    func save(_ photoEvidence: PhotoEvidence) throws {
        try database.execute(
            """
            INSERT INTO photo_evidence (
                id,
                report_id,
                local_file_path,
                exif_lat,
                exif_lon,
                captured_at,
                has_metadata,
                checksum,
                created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                report_id = excluded.report_id,
                local_file_path = excluded.local_file_path,
                exif_lat = excluded.exif_lat,
                exif_lon = excluded.exif_lon,
                captured_at = excluded.captured_at,
                has_metadata = excluded.has_metadata,
                checksum = excluded.checksum,
                created_at = excluded.created_at;
            """,
            bindings: [
                .text(photoEvidence.id.uuidString),
                .text(photoEvidence.reportID.uuidString),
                .text(photoEvidence.localFilePath),
                doubleOrNull(photoEvidence.exifCoordinate?.latitude),
                doubleOrNull(photoEvidence.exifCoordinate?.longitude),
                textOrNull(photoEvidence.capturedAt.map(DateCoding.string)),
                .bool(photoEvidence.hasMetadata),
                textOrNull(photoEvidence.checksum),
                .text(DateCoding.string(from: photoEvidence.createdAt))
            ]
        )
    }

    func fetchPhotoEvidence(for reportID: UUID) throws -> [PhotoEvidence] {
        try database.query(
            "SELECT * FROM photo_evidence WHERE report_id = ? ORDER BY captured_at ASC;",
            bindings: [.text(reportID.uuidString)]
        )
        .compactMap { row -> PhotoEvidence? in
            guard
                let idString = row.string("id"),
                let id = UUID(uuidString: idString),
                let localFilePath = row.string("local_file_path")
            else {
                return nil
            }

            return PhotoEvidence(
                id: id,
                reportID: reportID,
                localFilePath: localFilePath,
                exifCoordinate: makeCoordinate(lat: row.double("exif_lat"), lon: row.double("exif_lon")),
                capturedAt: row.string("captured_at").flatMap(DateCoding.date),
                hasMetadata: row.bool("has_metadata") ?? false,
                checksum: row.string("checksum"),
                createdAt: row.string("created_at").flatMap(DateCoding.date) ?? Date(timeIntervalSince1970: 0)
            )
        }
    }

    func fetch(id: UUID) throws -> PhotoEvidence? {
        try database.query(
            "SELECT * FROM photo_evidence WHERE id = ? LIMIT 1;",
            bindings: [.text(id.uuidString)]
        )
        .compactMap { row -> PhotoEvidence? in
            guard
                let reportIDString = row.string("report_id"),
                let reportID = UUID(uuidString: reportIDString),
                let localFilePath = row.string("local_file_path")
            else {
                return nil
            }

            return PhotoEvidence(
                id: id,
                reportID: reportID,
                localFilePath: localFilePath,
                exifCoordinate: makeCoordinate(lat: row.double("exif_lat"), lon: row.double("exif_lon")),
                capturedAt: row.string("captured_at").flatMap(DateCoding.date),
                hasMetadata: row.bool("has_metadata") ?? false,
                checksum: row.string("checksum"),
                createdAt: row.string("created_at").flatMap(DateCoding.date) ?? Date(timeIntervalSince1970: 0)
            )
        }
        .first
    }
}
