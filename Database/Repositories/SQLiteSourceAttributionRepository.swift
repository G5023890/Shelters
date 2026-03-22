import Foundation

final class SQLiteSourceAttributionRepository: SourceAttributionRepository {
    private let database: SQLiteDatabase

    init(database: SQLiteDatabase) {
        self.database = database
    }

    func fetchSourceAttributions(for placeID: UUID) throws -> [PlaceSourceAttribution] {
        try database.query(
            """
            SELECT id, canonical_place_id, source_name, source_identifier, imported_at
            FROM source_attribution
            WHERE canonical_place_id = ? COLLATE NOCASE
            ORDER BY imported_at DESC, source_name ASC;
            """,
            bindings: [.text(placeID.uuidString)]
        )
        .map(mapRow)
    }

    private func mapRow(_ row: SQLiteRow) throws -> PlaceSourceAttribution {
        guard
            let idString = row.string("id"),
            let id = UUID(uuidString: idString),
            let canonicalPlaceIDString = row.string("canonical_place_id"),
            let canonicalPlaceID = UUID(uuidString: canonicalPlaceIDString),
            let sourceName = row.string("source_name"),
            let importedAtString = row.string("imported_at"),
            let importedAt = DateCoding.date(from: importedAtString)
        else {
            throw SQLiteError.invalidValue(column: "source_attribution")
        }

        return PlaceSourceAttribution(
            id: id,
            canonicalPlaceID: canonicalPlaceID,
            sourceName: sourceName,
            sourceIdentifier: row.string("source_identifier"),
            importedAt: importedAt
        )
    }
}
