import Foundation

final class SQLiteCanonicalPlaceRepository: CanonicalPlaceRepository {
    private let database: SQLiteDatabase

    init(database: SQLiteDatabase) {
        self.database = database
    }

    func upsert(_ places: [CanonicalPlace]) throws {
        guard !places.isEmpty else { return }

        try database.transaction { connection in
            for place in places {
                let routingCoordinate = place.routingCoordinate

                try connection.execute(
                    """
                    INSERT INTO canonical_places (
                        id,
                        name_original,
                        name_en,
                        name_ru,
                        name_he,
                        address_original,
                        address_en,
                        address_ru,
                        address_he,
                        city,
                        place_type,
                        object_lat,
                        object_lon,
                        entrance_lat,
                        entrance_lon,
                        preferred_routing_lat,
                        preferred_routing_lon,
                        preferred_routing_point_type,
                        search_tile_key,
                        is_public,
                        is_accessible,
                        status,
                        confidence_score,
                        routing_quality,
                        last_verified_at,
                        created_at,
                        updated_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(id) DO UPDATE SET
                        name_original = excluded.name_original,
                        name_en = excluded.name_en,
                        name_ru = excluded.name_ru,
                        name_he = excluded.name_he,
                        address_original = excluded.address_original,
                        address_en = excluded.address_en,
                        address_ru = excluded.address_ru,
                        address_he = excluded.address_he,
                        city = excluded.city,
                        place_type = excluded.place_type,
                        object_lat = excluded.object_lat,
                        object_lon = excluded.object_lon,
                        entrance_lat = excluded.entrance_lat,
                        entrance_lon = excluded.entrance_lon,
                        preferred_routing_lat = excluded.preferred_routing_lat,
                        preferred_routing_lon = excluded.preferred_routing_lon,
                        preferred_routing_point_type = excluded.preferred_routing_point_type,
                        search_tile_key = excluded.search_tile_key,
                        is_public = excluded.is_public,
                        is_accessible = excluded.is_accessible,
                        status = excluded.status,
                        confidence_score = excluded.confidence_score,
                        routing_quality = excluded.routing_quality,
                        last_verified_at = excluded.last_verified_at,
                        created_at = excluded.created_at,
                        updated_at = excluded.updated_at;
                    """,
                    bindings: [
                        .text(place.id.uuidString),
                        textOrNull(place.name.original),
                        textOrNull(place.name.english),
                        textOrNull(place.name.russian),
                        textOrNull(place.name.hebrew),
                        textOrNull(place.address.original),
                        textOrNull(place.address.english),
                        textOrNull(place.address.russian),
                        textOrNull(place.address.hebrew),
                        textOrNull(place.city),
                        .text(place.placeType.rawValue),
                        .double(place.objectCoordinate.latitude),
                        .double(place.objectCoordinate.longitude),
                        doubleOrNull(place.entranceCoordinate?.latitude),
                        doubleOrNull(place.entranceCoordinate?.longitude),
                        .double(routingCoordinate.latitude),
                        .double(routingCoordinate.longitude),
                        textOrNull(place.preferredRoutingPointType?.rawValue),
                        .text(SearchTileKey.make(for: routingCoordinate)),
                        .bool(place.isPublic),
                        .bool(place.isAccessible),
                        .text(place.status.rawValue),
                        .double(place.confidenceScore),
                        .double(place.routingQuality),
                        textOrNull(place.lastVerifiedAt.map(DateCoding.string)),
                        .text(DateCoding.string(from: place.createdAt)),
                        .text(DateCoding.string(from: place.updatedAt))
                    ]
                )
            }
        }
    }

    func fetchAll(limit: Int?) throws -> [CanonicalPlace] {
        let sql: String
        let bindings: [SQLiteValue]

        if let limit {
            sql = "SELECT * FROM canonical_places ORDER BY updated_at DESC LIMIT ?;"
            bindings = [.integer(Int64(limit))]
        } else {
            sql = "SELECT * FROM canonical_places ORDER BY updated_at DESC;"
            bindings = []
        }

        return try database.query(sql, bindings: bindings).map(Self.mapRow)
    }

    func fetch(id: UUID) throws -> CanonicalPlace? {
        try database.query(
            "SELECT * FROM canonical_places WHERE id = ? COLLATE NOCASE LIMIT 1;",
            bindings: [.text(id.uuidString)]
        )
        .first
        .map(Self.mapRow)
    }

    func fetchNearbyCandidates(around coordinate: GeoCoordinate, radiusMeters: Double, limit: Int) throws -> [CanonicalPlace] {
        let bounds = DistanceCalculator.searchBounds(around: coordinate, radiusMeters: radiusMeters)
        let tileKeys = SearchTileKey.neighborhoodKeys(around: coordinate, radiusMeters: radiusMeters)
        let tilePlaceholders = Array(repeating: "?", count: tileKeys.count).joined(separator: ", ")

        var bindings = tileKeys.map(SQLiteValue.text)
        bindings.append(.double(bounds.minLatitude))
        bindings.append(.double(bounds.maxLatitude))
        bindings.append(.double(bounds.minLongitude))
        bindings.append(.double(bounds.maxLongitude))
        bindings.append(.text(PlaceStatus.removed.rawValue))
        bindings.append(.integer(Int64(limit)))

        return try database.query(
            """
            SELECT *
            FROM canonical_places
            WHERE (
                    search_tile_key IN (\(tilePlaceholders))
                    OR search_tile_key IS NULL
                  )
              AND preferred_routing_lat BETWEEN ? AND ?
              AND preferred_routing_lon BETWEEN ? AND ?
              AND status != ?
            ORDER BY updated_at DESC
            LIMIT ?;
            """,
            bindings: bindings
        )
        .map(Self.mapRow)
    }

    func count() throws -> Int {
        let row = try database.query("SELECT COUNT(*) AS count FROM canonical_places LIMIT 1;").first
        return Int(row?.int64("count") ?? 0)
    }

    private static func mapRow(_ row: SQLiteRow) throws -> CanonicalPlace {
        guard
            let idString = row.string("id"),
            let id = UUID(uuidString: idString),
            let placeTypeRaw = row.string("place_type"),
            let placeType = PlaceType(rawValue: placeTypeRaw),
            let statusRaw = row.string("status"),
            let status = PlaceStatus(rawValue: statusRaw),
            let objectLat = row.double("object_lat"),
            let objectLon = row.double("object_lon"),
            let preferredLat = row.double("preferred_routing_lat"),
            let preferredLon = row.double("preferred_routing_lon"),
            let createdAtString = row.string("created_at"),
            let createdAt = DateCoding.date(from: createdAtString),
            let updatedAtString = row.string("updated_at"),
            let updatedAt = DateCoding.date(from: updatedAtString)
        else {
            throw SQLiteError.invalidValue(column: "canonical_places")
        }

        let entranceCoordinate: GeoCoordinate?
        if let entranceLat = row.double("entrance_lat"), let entranceLon = row.double("entrance_lon") {
            entranceCoordinate = GeoCoordinate(latitude: entranceLat, longitude: entranceLon)
        } else {
            entranceCoordinate = nil
        }

        let lastVerifiedAt = row.string("last_verified_at").flatMap(DateCoding.date)

        return CanonicalPlace(
            id: id,
            name: LocalizedPlaceText(
                original: row.string("name_original"),
                english: row.string("name_en"),
                russian: row.string("name_ru"),
                hebrew: row.string("name_he")
            ),
            address: LocalizedPlaceText(
                original: row.string("address_original"),
                english: row.string("address_en"),
                russian: row.string("address_ru"),
                hebrew: row.string("address_he")
            ),
            city: row.string("city"),
            placeType: placeType,
            objectCoordinate: GeoCoordinate(latitude: objectLat, longitude: objectLon),
            entranceCoordinate: entranceCoordinate,
            preferredRoutingCoordinate: GeoCoordinate(latitude: preferredLat, longitude: preferredLon),
            preferredRoutingPointType: row.string("preferred_routing_point_type").flatMap(RoutingPointType.init(rawValue:)),
            isPublic: row.bool("is_public") ?? false,
            isAccessible: row.bool("is_accessible") ?? false,
            status: status,
            confidenceScore: row.double("confidence_score") ?? 0,
            routingQuality: row.double("routing_quality") ?? 0,
            lastVerifiedAt: lastVerifiedAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
