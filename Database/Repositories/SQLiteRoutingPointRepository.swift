import Foundation

final class SQLiteRoutingPointRepository: RoutingPointRepository {
    private let database: SQLiteDatabase

    init(database: SQLiteDatabase) {
        self.database = database
    }

    func replaceRoutingPoints(_ routingPoints: [RoutingPoint], for placeID: UUID) throws {
        try database.transaction { connection in
            try connection.execute(
                "DELETE FROM routing_points WHERE canonical_place_id = ?;",
                bindings: [.text(placeID.uuidString)]
            )

            for routingPoint in routingPoints {
                try connection.execute(
                    """
                    INSERT INTO routing_points (
                        id,
                        canonical_place_id,
                        lat,
                        lon,
                        point_type,
                        confidence,
                        derived_from,
                        created_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?);
                    """,
                    bindings: [
                        .text(routingPoint.id.uuidString),
                        .text(routingPoint.canonicalPlaceID.uuidString),
                        .double(routingPoint.coordinate.latitude),
                        .double(routingPoint.coordinate.longitude),
                        .text(routingPoint.pointType.rawValue),
                        .double(routingPoint.confidence),
                        textOrNull(routingPoint.derivedFrom),
                        .text(DateCoding.string(from: routingPoint.createdAt))
                    ]
                )
            }
        }
    }

    func fetchRoutingPoints(for placeID: UUID) throws -> [RoutingPoint] {
        try database.query(
            """
            SELECT *
            FROM routing_points
            WHERE canonical_place_id = ? COLLATE NOCASE
            ORDER BY confidence DESC, created_at ASC;
            """,
            bindings: [.text(placeID.uuidString)]
        )
        .compactMap { row in
            guard
                let idString = row.string("id"),
                let id = UUID(uuidString: idString),
                let lat = row.double("lat"),
                let lon = row.double("lon"),
                let pointTypeRaw = row.string("point_type"),
                let pointType = RoutingPointType(rawValue: pointTypeRaw),
                let createdAtString = row.string("created_at"),
                let createdAt = DateCoding.date(from: createdAtString)
            else {
                return nil
            }

            return RoutingPoint(
                id: id,
                canonicalPlaceID: placeID,
                coordinate: GeoCoordinate(latitude: lat, longitude: lon),
                pointType: pointType,
                confidence: row.double("confidence") ?? 0,
                derivedFrom: row.string("derived_from"),
                createdAt: createdAt
            )
        }
    }
}
