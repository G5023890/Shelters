import CryptoKit
import Foundation

enum DatasetInputSelection: Equatable {
    case curatedJSON(URL)
    case externalSource(ExternalSourceKind, snapshotURL: URL?)
}

struct BuilderConfiguration {
    let inputSelection: DatasetInputSelection
    let outputDirectoryURL: URL
    let downloadBaseURL: URL

    static func parse(arguments: [String]) throws -> BuilderConfiguration {
        let currentDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let defaultInputURL = currentDirectory.appendingPathComponent(
            "Tools/DatasetBuilder/Input/curated-sample-places.json"
        )

        var inputSelection: DatasetInputSelection = .curatedJSON(defaultInputURL)
        var outputDirectoryURL = currentDirectory.appendingPathComponent("Tools/DatasetBuilder/Output")
        var downloadBaseURL = URL(string: "http://127.0.0.1:8000")!

        var pendingInputURL: URL?
        var pendingSourceKind: ExternalSourceKind?
        var pendingSourceSnapshotURL: URL?

        var iterator = arguments.makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--input":
                guard let value = iterator.next() else {
                    throw DatasetBuilderError.invalidArgument("--input requires a file path.")
                }
                pendingInputURL = URL(fileURLWithPath: value, relativeTo: currentDirectory).standardizedFileURL
            case "--source":
                guard let value = iterator.next(), let kind = ExternalSourceKind(rawValue: value) else {
                    throw DatasetBuilderError.invalidArgument(
                        "--source requires one of: \(ExternalSourceKind.allCases.map(\.rawValue).joined(separator: ", "))."
                    )
                }
                pendingSourceKind = kind
            case "--source-snapshot":
                guard let value = iterator.next() else {
                    throw DatasetBuilderError.invalidArgument("--source-snapshot requires a file path.")
                }
                pendingSourceSnapshotURL = URL(fileURLWithPath: value, relativeTo: currentDirectory).standardizedFileURL
            case "--output-dir":
                guard let value = iterator.next() else {
                    throw DatasetBuilderError.invalidArgument("--output-dir requires a directory path.")
                }
                outputDirectoryURL = URL(fileURLWithPath: value, relativeTo: currentDirectory).standardizedFileURL
            case "--download-base-url":
                guard let value = iterator.next(), let url = URL(string: value) else {
                    throw DatasetBuilderError.invalidArgument("--download-base-url requires a valid URL.")
                }
                downloadBaseURL = url
            case "--help":
                printUsage()
                exit(EXIT_SUCCESS)
            default:
                throw DatasetBuilderError.invalidArgument("Unsupported argument: \(argument)")
            }
        }

        if pendingInputURL != nil && pendingSourceKind != nil {
            throw DatasetBuilderError.invalidArgument("--input and --source cannot be used together.")
        }

        if let pendingSourceKind {
            inputSelection = .externalSource(pendingSourceKind, snapshotURL: pendingSourceSnapshotURL)
        } else if let pendingInputURL {
            inputSelection = .curatedJSON(pendingInputURL)
        } else if pendingSourceSnapshotURL != nil {
            throw DatasetBuilderError.invalidArgument("--source-snapshot requires --source.")
        }

        return BuilderConfiguration(
            inputSelection: inputSelection,
            outputDirectoryURL: outputDirectoryURL,
            downloadBaseURL: downloadBaseURL
        )
    }

    static func printUsage() {
        let usage = """
        Usage:
          Tools/DatasetBuilder/build_sample_dataset.sh [options]

        Options:
          --input <path>               Path to curated sample JSON input.
          --source <kind>              External source identifier.
          --source-snapshot <path>     Local raw source snapshot to ingest instead of live fetch.
          --output-dir <path>          Directory for generated artifacts.
          --download-base-url <url>    Base URL written into dataset-metadata.json.
          --help                       Show this help.

        Supported external sources:
          \(ExternalSourceKind.allCases.map(\.rawValue).joined(separator: "\n  "))
        """
        print(usage)
    }
}

final class DatasetBuilder {
    private let configuration: BuilderConfiguration
    private let fileManager: FileManager
    private let dataLoader: URLDataLoading

    init(
        configuration: BuilderConfiguration,
        fileManager: FileManager = .default,
        dataLoader: URLDataLoading = DataURLLoader()
    ) {
        self.configuration = configuration
        self.fileManager = fileManager
        self.dataLoader = dataLoader
    }

    func run() throws {
        let manifest = try loadManifest()
        try validate(manifest: manifest)
        try prepareOutputDirectory()

        let workingDatabaseURL = configuration.outputDirectoryURL.appendingPathComponent("working.sqlite")
        let snapshotURL = configuration.outputDirectoryURL.appendingPathComponent("shelters.sqlite")
        let metadataURL = configuration.outputDirectoryURL.appendingPathComponent("dataset-metadata.json")
        let reviewURL = configuration.outputDirectoryURL.appendingPathComponent("dedupe-review.json")

        try removeIfPresent(at: workingDatabaseURL)
        try removeIfPresent(at: snapshotURL)
        try removeIfPresent(at: metadataURL)
        try removeIfPresent(at: reviewURL)

        defer {
            try? removeIfPresent(at: workingDatabaseURL)
            try? removeIfPresent(at: workingDatabaseURL.appendingPathExtension("wal"))
            try? removeIfPresent(at: workingDatabaseURL.appendingPathExtension("shm"))
        }

        do {
            let database = try SQLiteDatabase(path: workingDatabaseURL.path)
            try DatabaseMigrator().migrate(database)
            try database.execute(
                "UPDATE schema_migrations SET applied_at = ?;",
                bindings: [.text(manifest.publishedAt)]
            )

            try database.transaction { connection in
                for place in manifest.places.sorted(by: { $0.id < $1.id }) {
                    try insert(place: place, defaultSourceName: manifest.defaultSourceName, into: connection)
                }
            }

            try database.execute("PRAGMA wal_checkpoint(TRUNCATE);")
            try database.execute(
                "VACUUM INTO ?;",
                bindings: [.text(snapshotURL.path)]
            )
        }

        let checksum = try sha256(for: snapshotURL)
        let fileSize = try fileSize(at: snapshotURL)
        let metadata = GeneratedDatasetMetadata(
            datasetVersion: manifest.datasetVersion,
            publishedAt: manifest.publishedAt,
            schemaVersion: DatabaseSchemaMigrations.latestVersion,
            checksum: checksum,
            downloadURL: makeDownloadURL(),
            recordCount: manifest.places.count,
            buildNumber: manifest.buildNumber,
            minimumClientVersion: manifest.minimumClientVersion,
            fileSize: fileSize
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let metadataData = try encoder.encode(metadata)
        try metadataData.write(to: metadataURL, options: .atomic)

        if let reviewReport = manifest.reviewReport {
            let reviewData = try encoder.encode(reviewReport)
            try reviewData.write(to: reviewURL, options: .atomic)
        }

        print("Generated dataset artifacts:")
        print("  SQLite: \(snapshotURL.path)")
        print("  Metadata: \(metadataURL.path)")
        if manifest.reviewReport != nil {
            print("  Dedupe review: \(reviewURL.path)")
        }
        print("  Version: \(manifest.datasetVersion)")
        print("  Records: \(manifest.places.count)")
        print("  Checksum: \(checksum)")
    }

    private func loadManifest() throws -> DatasetBuildManifest {
        switch configuration.inputSelection {
        case .curatedJSON(let inputURL):
            guard fileManager.fileExists(atPath: inputURL.path) else {
                throw DatasetBuilderError.inputMissing(inputURL.path)
            }

            let inputData = try Data(contentsOf: inputURL)
            let input = try JSONDecoder().decode(CuratedDatasetInput.self, from: inputData)
            return input.makeManifest()

        case .externalSource(let sourceKind, let snapshotURL):
            let connector = sourceKind.makeConnector(dataLoader: dataLoader)
            return try connector.buildManifest(snapshotURL: snapshotURL)
        }
    }

    private func validate(manifest: DatasetBuildManifest) throws {
        guard !manifest.places.isEmpty else {
            throw DatasetBuilderError.invalidArgument("Dataset must contain at least one place record.")
        }

        guard DateCoding.date(from: manifest.publishedAt) != nil else {
            throw DatasetBuilderError.invalidInputDate("dataset publishedAt")
        }

        if case .curatedJSON = configuration.inputSelection, !(20...50).contains(manifest.places.count) {
            throw DatasetBuilderError.invalidRecordCount(manifest.places.count)
        }

        let placeIDs = Set(manifest.places.map(\.id))
        guard placeIDs.count == manifest.places.count else {
            throw DatasetBuilderError.invalidArgument("Place IDs must be unique.")
        }

        for place in manifest.places {
            guard DateCoding.date(from: place.createdAt) != nil else {
                throw DatasetBuilderError.invalidInputDate("createdAt for \(place.id)")
            }

            guard DateCoding.date(from: place.updatedAt) != nil else {
                throw DatasetBuilderError.invalidInputDate("updatedAt for \(place.id)")
            }

            if let lastVerifiedAt = place.lastVerifiedAt,
               DateCoding.date(from: lastVerifiedAt) == nil {
                throw DatasetBuilderError.invalidInputDate("lastVerifiedAt for \(place.id)")
            }

            if place.entranceLat != nil, place.entranceLon == nil {
                throw DatasetBuilderError.invalidArgument(
                    "entranceLon is required when entranceLat is set for \(place.id)"
                )
            }

            if place.entranceLon != nil, place.entranceLat == nil {
                throw DatasetBuilderError.invalidArgument(
                    "entranceLat is required when entranceLon is set for \(place.id)"
                )
            }
        }
    }

    private func prepareOutputDirectory() throws {
        try fileManager.createDirectory(
            at: configuration.outputDirectoryURL,
            withIntermediateDirectories: true
        )
    }

    private func insert(
        place: DatasetPlaceRecord,
        defaultSourceName: String?,
        into connection: SQLiteConnection
    ) throws {
        let preferredTarget = preferredRoutingTarget(for: place)

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
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """,
            bindings: [
                .text(place.id),
                optionalText(place.nameOriginal),
                optionalText(place.nameEn),
                optionalText(place.nameRu),
                optionalText(place.nameHe),
                optionalText(place.addressOriginal),
                optionalText(place.addressEn),
                optionalText(place.addressRu),
                optionalText(place.addressHe),
                optionalText(place.city),
                .text(place.placeType),
                .double(place.objectLat),
                .double(place.objectLon),
                optionalDouble(place.entranceLat),
                optionalDouble(place.entranceLon),
                .double(preferredTarget.latitude),
                .double(preferredTarget.longitude),
                .text(preferredTarget.pointType),
                .text(makeSearchTileKey(latitude: preferredTarget.latitude, longitude: preferredTarget.longitude)),
                .bool(place.isPublic),
                .bool(place.isAccessible),
                .text(place.status),
                .double(place.confidenceScore),
                .double(place.routingQuality),
                optionalText(place.lastVerifiedAt),
                .text(place.createdAt),
                .text(place.updatedAt)
            ]
        )

        for routingPoint in place.routingPoints.sorted(by: { $0.id < $1.id }) {
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
                    .text(routingPoint.id),
                    .text(place.id),
                    .double(routingPoint.lat),
                    .double(routingPoint.lon),
                    .text(routingPoint.pointType),
                    .double(routingPoint.confidence),
                    optionalText(routingPoint.derivedFrom),
                    .text(routingPoint.createdAt ?? place.createdAt)
                ]
            )
        }

        let sourceAttributions = place.sourceAttributions.isEmpty
            ? fallbackSourceAttributions(for: place, defaultSourceName: defaultSourceName)
            : place.sourceAttributions

        for attribution in sourceAttributions {
            try connection.execute(
                """
                INSERT INTO source_attribution (
                    id,
                    canonical_place_id,
                    source_name,
                    source_identifier,
                    imported_at
                ) VALUES (?, ?, ?, ?, ?);
                """,
                bindings: [
                    .text(attribution.id),
                    .text(place.id),
                    .text(attribution.sourceName),
                    optionalText(attribution.sourceIdentifier),
                    .text(attribution.importedAt ?? place.updatedAt)
                ]
            )
        }
    }

    private func preferredRoutingTarget(for place: DatasetPlaceRecord) -> PreferredTarget {
        if let entranceLat = place.entranceLat, let entranceLon = place.entranceLon {
            return PreferredTarget(latitude: entranceLat, longitude: entranceLon, pointType: "entrance")
        }

        if let strongestRoutingPoint = place.routingPoints.max(by: {
            if $0.confidence == $1.confidence {
                return $0.id < $1.id
            }
            return $0.confidence < $1.confidence
        }) {
            return PreferredTarget(
                latitude: strongestRoutingPoint.lat,
                longitude: strongestRoutingPoint.lon,
                pointType: strongestRoutingPoint.pointType
            )
        }

        return PreferredTarget(latitude: place.objectLat, longitude: place.objectLon, pointType: "object")
    }

    private func makeSearchTileKey(latitude: Double, longitude: Double, precision: Double = 0.05) -> String {
        let latBucket = Int(floor(latitude / precision))
        let lonBucket = Int(floor(longitude / precision))
        return "\(latBucket)_\(lonBucket)"
    }

    private func makeDownloadURL() -> URL {
        configuration.downloadBaseURL.appendingPathComponent("shelters.sqlite")
    }

    private func fileSize(at url: URL) throws -> Int64 {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? NSNumber)?.int64Value ?? 0
    }

    private func sha256(for url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func removeIfPresent(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }

        try fileManager.removeItem(at: url)
    }

    private func optionalDouble(_ value: Double?) -> SQLiteValue {
        value.map(SQLiteValue.double) ?? .null
    }

    private func optionalText(_ value: String?) -> SQLiteValue {
        value.map(SQLiteValue.text) ?? .null
    }

    private func fallbackSourceAttributions(
        for place: DatasetPlaceRecord,
        defaultSourceName: String?
    ) -> [DatasetSourceAttributionRecord] {
        guard let sourceName = place.sourceName ?? defaultSourceName else {
            return []
        }

        return [
            DatasetSourceAttributionRecord(
                id: "\(place.id)-source",
                sourceName: sourceName,
                sourceIdentifier: place.sourceIdentifier,
                importedAt: place.updatedAt
            )
        ]
    }
}

struct PreferredTarget {
    let latitude: Double
    let longitude: Double
    let pointType: String
}

struct DatasetBuildManifest {
    let datasetVersion: String
    let publishedAt: String
    let buildNumber: Int
    let minimumClientVersion: String?
    let defaultSourceName: String?
    let places: [DatasetPlaceRecord]
    let reviewReport: DedupeReviewReport?
}

struct DatasetPlaceRecord {
    let id: String
    let nameOriginal: String?
    let nameEn: String?
    let nameRu: String?
    let nameHe: String?
    let addressOriginal: String?
    let addressEn: String?
    let addressRu: String?
    let addressHe: String?
    let city: String?
    let placeType: String
    let objectLat: Double
    let objectLon: Double
    let entranceLat: Double?
    let entranceLon: Double?
    let isPublic: Bool
    let isAccessible: Bool
    let status: String
    let confidenceScore: Double
    let routingQuality: Double
    let lastVerifiedAt: String?
    let createdAt: String
    let updatedAt: String
    let sourceName: String?
    let sourceIdentifier: String?
    let routingPoints: [DatasetRoutingPointRecord]
    let sourceAttributions: [DatasetSourceAttributionRecord]
}

struct DatasetRoutingPointRecord {
    let id: String
    let lat: Double
    let lon: Double
    let pointType: String
    let confidence: Double
    let derivedFrom: String?
    let createdAt: String?
}

struct DatasetSourceAttributionRecord {
    let id: String
    let sourceName: String
    let sourceIdentifier: String?
    let importedAt: String?
}

struct CuratedDatasetInput: Decodable {
    let datasetVersion: String
    let publishedAt: String
    let buildNumber: Int
    let minimumClientVersion: String?
    let defaultSourceName: String?
    let places: [CuratedPlaceRecord]

    func makeManifest() -> DatasetBuildManifest {
        DatasetBuildManifest(
            datasetVersion: datasetVersion,
            publishedAt: publishedAt,
            buildNumber: buildNumber,
            minimumClientVersion: minimumClientVersion,
            defaultSourceName: defaultSourceName,
            places: places.map(\.datasetPlaceRecord),
            reviewReport: nil
        )
    }
}

struct CuratedPlaceRecord: Decodable {
    let id: String
    let nameOriginal: String?
    let nameEn: String?
    let nameRu: String?
    let nameHe: String?
    let addressOriginal: String?
    let addressEn: String?
    let addressRu: String?
    let addressHe: String?
    let city: String?
    let placeType: String
    let objectLat: Double
    let objectLon: Double
    let entranceLat: Double?
    let entranceLon: Double?
    let isPublic: Bool
    let isAccessible: Bool
    let status: String
    let confidenceScore: Double
    let routingQuality: Double
    let lastVerifiedAt: String?
    let createdAt: String
    let updatedAt: String
    let sourceName: String?
    let sourceIdentifier: String?
    let routingPoints: [CuratedRoutingPointRecord]

    var datasetPlaceRecord: DatasetPlaceRecord {
        DatasetPlaceRecord(
            id: id,
            nameOriginal: nameOriginal,
            nameEn: nameEn,
            nameRu: nameRu,
            nameHe: nameHe,
            addressOriginal: addressOriginal,
            addressEn: addressEn,
            addressRu: addressRu,
            addressHe: addressHe,
            city: city,
            placeType: placeType,
            objectLat: objectLat,
            objectLon: objectLon,
            entranceLat: entranceLat,
            entranceLon: entranceLon,
            isPublic: isPublic,
            isAccessible: isAccessible,
            status: status,
            confidenceScore: confidenceScore,
            routingQuality: routingQuality,
            lastVerifiedAt: lastVerifiedAt,
            createdAt: createdAt,
            updatedAt: updatedAt,
            sourceName: sourceName,
            sourceIdentifier: sourceIdentifier,
            routingPoints: routingPoints.map(\.datasetRoutingPointRecord),
            sourceAttributions: sourceName.map {
                [
                    DatasetSourceAttributionRecord(
                        id: "\(id)-source",
                        sourceName: $0,
                        sourceIdentifier: sourceIdentifier,
                        importedAt: updatedAt
                    )
                ]
            } ?? []
        )
    }
}

struct CuratedRoutingPointRecord: Decodable {
    let id: String
    let lat: Double
    let lon: Double
    let pointType: String
    let confidence: Double
    let derivedFrom: String?
    let createdAt: String?

    var datasetRoutingPointRecord: DatasetRoutingPointRecord {
        DatasetRoutingPointRecord(
            id: id,
            lat: lat,
            lon: lon,
            pointType: pointType,
            confidence: confidence,
            derivedFrom: derivedFrom,
            createdAt: createdAt
        )
    }
}

struct GeneratedDatasetMetadata: Encodable {
    let datasetVersion: String
    let publishedAt: String
    let schemaVersion: Int
    let checksum: String
    let downloadURL: URL
    let recordCount: Int
    let buildNumber: Int
    let minimumClientVersion: String?
    let fileSize: Int64
}

enum DatasetBuilderError: LocalizedError {
    case invalidArgument(String)
    case inputMissing(String)
    case invalidInputDate(String)
    case invalidRecordCount(Int)
    case sourceSnapshotMissing(String)
    case sourceResourceNotFound(String)

    var errorDescription: String? {
        switch self {
        case .invalidArgument(let message):
            return message
        case .inputMissing(let path):
            return "Dataset builder input file was not found at \(path)."
        case .invalidInputDate(let field):
            return "Input date value is invalid for \(field)."
        case .invalidRecordCount(let count):
            return "Curated input must contain between 20 and 50 records. Current count: \(count)."
        case .sourceSnapshotMissing(let path):
            return "Source snapshot file was not found at \(path)."
        case .sourceResourceNotFound(let message):
            return message
        }
    }
}
