import Foundation

enum ExternalSourceKind: String, CaseIterable {
    case beerShevaShelters = "beer-sheva-shelters"
    case beerShevaSheltersITM = "beer-sheva-shelters-itm"
    case beerShevaCanonicalV1 = "beer-sheva-canonical-v1"
    case petahTikvaOfficialV1 = "petah-tikva-official-v1"
    case telAvivOfficialV1 = "tel-aviv-official-v1"
    case jerusalemOfficialV1 = "jerusalem-official-v1"
    case miklatNationalV1 = "miklat-national-v1"
    case israelPreviewV1 = "israel-preview-v1"

    func makeConnector(dataLoader: URLDataLoading) -> ExternalSourceConnector {
        switch self {
        case .beerShevaShelters:
            BeerShevaSheltersConnector(dataLoader: dataLoader)
        case .beerShevaSheltersITM:
            BeerShevaSheltersITMConnector(dataLoader: dataLoader)
        case .beerShevaCanonicalV1:
            BeerShevaCanonicalConnector(dataLoader: dataLoader)
        case .petahTikvaOfficialV1:
            PetahTikvaOfficialConnector(dataLoader: dataLoader)
        case .telAvivOfficialV1:
            TelAvivOfficialConnector(dataLoader: dataLoader)
        case .jerusalemOfficialV1:
            JerusalemOfficialConnector(dataLoader: dataLoader)
        case .miklatNationalV1:
            MiklatNationalConnector(dataLoader: dataLoader)
        case .israelPreviewV1:
            IsraelPreviewConnector(dataLoader: dataLoader)
        }
    }
}

protocol ExternalSourceConnector {
    func buildManifest(snapshotURL: URL?) throws -> DatasetBuildManifest
}

protocol URLDataLoading {
    func load(from url: URL) throws -> Data
}

struct DataURLLoader: URLDataLoading {
    func load(from url: URL) throws -> Data {
        try Data(contentsOf: url)
    }
}

private enum BeerShevaDatasetConstants {
    static let packageID = "shelters-br7"
    static let packagePageURL = URL(string: "https://data.gov.il/dataset/shelters-br7")!
    static let cityName = "Beer Sheva"
    static let supportedClientVersion = "1.0.0"
    static let datastorePageSize = 500
}

private enum IsraelPreviewDatasetConstants {
    static let curatedSeedFileName = "curated-sample-places.json"
}

private enum PetahTikvaDatasetConstants {
    static let cityName = "Petah Tikva"
    static let supportedClientVersion = "1.0.0"

    static let institutionsLayer = ArcGISFeatureLayerSource(
        sourceName: "petah-tikva-protected-spaces-institutions",
        sourceLayerName: "protected-spaces-institutions",
        dataURL: URL(
            string: "https://services9.arcgis.com/tfeLX7LFVABzD11G/arcgis/rest/services/%D7%9E%D7%A7%D7%9C%D7%98%D7%99%D7%9D_%D7%95%D7%9E%D7%97%D7%A1%D7%95%D7%AA_%D7%9C%D7%90%D7%92%D7%95%D7%9C/FeatureServer/179"
        )!,
        sourceConfidence: 0.90,
        sourceRoutingQuality: 0.76
    )

    static let publicLayer = ArcGISFeatureLayerSource(
        sourceName: "petah-tikva-protected-spaces-public",
        sourceLayerName: "protected-spaces-public",
        dataURL: URL(
            string: "https://services9.arcgis.com/tfeLX7LFVABzD11G/arcgis/rest/services/%D7%9E%D7%A8%D7%97%D7%91%D7%99%D7%9D/FeatureServer/0"
        )!,
        sourceConfidence: 0.92,
        sourceRoutingQuality: 0.78
    )

    static let refugesLayer = ArcGISFeatureLayerSource(
        sourceName: "petah-tikva-refuges",
        sourceLayerName: "refuges",
        dataURL: URL(
            string: "https://services9.arcgis.com/tfeLX7LFVABzD11G/arcgis/rest/services/%D7%9E%D7%97%D7%A1%D7%95%D7%AA/FeatureServer/4"
        )!,
        sourceConfidence: 0.91,
        sourceRoutingQuality: 0.80
    )
}

private enum MiklatDatasetConstants {
    static let supportedClientVersion = "1.0.0"
    static let dataVersionURL = URL(string: "https://miklat.co.il/ru/map/")!
    static let sheltersLiteURL = URL(string: "https://miklat.co.il/data/shelters-lite.json")!
    static let sheltersDetailsURL = URL(string: "https://miklat.co.il/data/shelters-details.json")!
    static let hebrewCityIndexURL = URL(string: "https://miklat.co.il/he/shelters/")!
    static let englishCityIndexURL = URL(string: "https://miklat.co.il/en/shelters/")!
    static let sourceName = "miklat-national-shelters"
    static let sourceConfidence = 0.58
    static let sourceRoutingQuality = 0.52
}

private enum TelAvivDatasetConstants {
    static let cityName = "Tel Aviv"
    static let supportedClientVersion = "1.0.0"

    static let sheltersLayer = ArcGISFeatureLayerSource(
        sourceName: "tel-aviv-municipal-shelters",
        sourceLayerName: "shelters",
        dataURL: URL(string: "https://gisn.tel-aviv.gov.il/ArcGIS/rest/services/IView2Test/MapServer/592")!,
        sourceConfidence: 0.94,
        sourceRoutingQuality: 0.83
    )
}

private enum JerusalemDatasetConstants {
    static let cityName = "Jerusalem"
    static let supportedClientVersion = "1.0.0"
    static let geoJSONURL = URL(
        string: "https://jerusalem.datacity.org.il/dataset/3e97d0fc-4268-4aea-844d-12588f55d809/resource/d8a3f5c9-c123-4ed7-88f4-62e1e2504032/download/data.geojson"
    )!
    static let sourceName = "jerusalem-public-shelters"
    static let sourceConfidence = 0.93
    static let sourceRoutingQuality = 0.81
}

private struct SourceBuildBundle {
    let datasetVersion: String
    let publishedAt: String
    let buildNumber: Int
    let minimumClientVersion: String?
    let defaultSourceName: String
    let normalizedRecords: [NormalizedSourcePlaceRecord]
}

final class BeerShevaSheltersConnector: ExternalSourceConnector {
    private static let resourceID = "e191d913-11e4-4d87-a4b2-91587aab6611"
    private static let sourceName = "beer-sheva-municipal-shelters"

    private let dataLoader: URLDataLoading
    private let decoder = JSONDecoder()

    init(dataLoader: URLDataLoading) {
        self.dataLoader = dataLoader
    }

    func buildManifest(snapshotURL: URL?) throws -> DatasetBuildManifest {
        let bundle = try loadBundle(snapshotURL: snapshotURL)
        return DatasetBuildManifest(
            datasetVersion: bundle.datasetVersion,
            publishedAt: bundle.publishedAt,
            buildNumber: bundle.buildNumber,
            minimumClientVersion: bundle.minimumClientVersion,
            defaultSourceName: bundle.defaultSourceName,
            places: bundle.normalizedRecords.map(mapToDatasetPlaceRecord),
            reviewReport: nil
        )
    }

    fileprivate func loadBundle(snapshotURL: URL?) throws -> SourceBuildBundle {
        let rawSnapshot = try loadRawSnapshot(snapshotURL: snapshotURL)
        let normalizedRecords = rawSnapshot.records.map { normalize(raw: $0, snapshot: rawSnapshot) }

        return SourceBuildBundle(
            datasetVersion: makeDatasetVersion(prefix: ExternalSourceKind.beerShevaShelters.rawValue, from: rawSnapshot.resourceLastModified),
            publishedAt: rawSnapshot.resourceLastModified,
            buildNumber: 1,
            minimumClientVersion: BeerShevaDatasetConstants.supportedClientVersion,
            defaultSourceName: Self.sourceName,
            normalizedRecords: normalizedRecords
        )
    }

    private func loadRawSnapshot(snapshotURL: URL?) throws -> BeerShevaSheltersRawSnapshot {
        if let snapshotURL {
            guard FileManager.default.fileExists(atPath: snapshotURL.path) else {
                throw DatasetBuilderError.sourceSnapshotMissing(snapshotURL.path)
            }

            let data = try Data(contentsOf: snapshotURL)
            let snapshot = try decoder.decode(BeerShevaSheltersRawSnapshot.self, from: data)
            return BeerShevaSheltersRawSnapshot(
                packageID: snapshot.packageID,
                packageTitle: snapshot.packageTitle,
                packagePageURL: snapshot.packagePageURL,
                resourceID: snapshot.resourceID,
                resourceName: snapshot.resourceName,
                resourceLastModified: normalizeTimestamp(snapshot.resourceLastModified),
                records: snapshot.records,
                fetchedAt: normalizeTimestamp(snapshot.fetchedAt)
            )
        }

        return try fetchLiveRawSnapshot()
    }

    private func fetchLiveRawSnapshot() throws -> BeerShevaSheltersRawSnapshot {
        let packageResponse = try fetchPackageResponse()
        let resource = try findResource(id: Self.resourceID, in: packageResponse.result.resources)
        let records: [BeerShevaShelterRawRecord] = try fetchDatastoreRecords(resourceID: Self.resourceID)

        return BeerShevaSheltersRawSnapshot(
            packageID: packageResponse.result.id,
            packageTitle: packageResponse.result.title,
            packagePageURL: BeerShevaDatasetConstants.packagePageURL.absoluteString,
            resourceID: resource.id,
            resourceName: resource.name,
            resourceLastModified: normalizeTimestamp(resource.lastModified),
            records: records,
            fetchedAt: DateCoding.string(from: Date())
        )
    }

    private func normalize(
        raw: BeerShevaShelterRawRecord,
        snapshot: BeerShevaSheltersRawSnapshot
    ) -> NormalizedSourcePlaceRecord {
        let trimmedCode = raw.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let sourceIdentifier = "\(snapshot.resourceID):\(raw.rowID)"

        return makeNormalizedRecord(
            stableID: deterministicUUIDString(from: sourceIdentifier),
            sourceName: Self.sourceName,
            sourceIdentifier: sourceIdentifier,
            displayCode: trimmedCode,
            objectLat: raw.latitude,
            objectLon: raw.longitude,
            lastVerifiedAt: snapshot.resourceLastModified,
            createdAt: snapshot.resourceLastModified,
            updatedAt: snapshot.resourceLastModified,
            sourceConfidence: 0.84,
            sourceRoutingQuality: 0.58
        )
    }

    private func mapToDatasetPlaceRecord(_ normalized: NormalizedSourcePlaceRecord) -> DatasetPlaceRecord {
        DatasetPlaceRecord(
            id: normalized.stableID,
            nameOriginal: normalized.nameOriginal,
            nameEn: normalized.nameEn,
            nameRu: normalized.nameRu,
            nameHe: normalized.nameHe,
            addressOriginal: normalized.addressOriginal,
            addressEn: normalized.addressEn,
            addressRu: normalized.addressRu,
            addressHe: normalized.addressHe,
            city: normalized.city,
            placeType: normalized.placeType,
            objectLat: normalized.objectLat,
            objectLon: normalized.objectLon,
            entranceLat: normalized.entranceLat,
            entranceLon: normalized.entranceLon,
            isPublic: normalized.isPublic,
            isAccessible: normalized.isAccessible,
            status: normalized.status,
            confidenceScore: normalized.sourceConfidence,
            routingQuality: normalized.sourceRoutingQuality,
            lastVerifiedAt: normalized.lastVerifiedAt,
            createdAt: normalized.createdAt,
            updatedAt: normalized.updatedAt,
            sourceName: normalized.sourceName,
            sourceIdentifier: normalized.sourceIdentifier,
            routingPoints: normalized.routingPoints.map { routingPoint in
                DatasetRoutingPointRecord(
                    id: routingPoint.id,
                    lat: routingPoint.lat,
                    lon: routingPoint.lon,
                    pointType: routingPoint.pointType,
                    confidence: routingPoint.confidence,
                    derivedFrom: routingPoint.derivedFrom,
                    createdAt: routingPoint.createdAt
                )
            },
            sourceAttributions: [
                DatasetSourceAttributionRecord(
                    id: deterministicUUIDString(from: "\(normalized.stableID)|\(normalized.sourceName)|\(normalized.sourceIdentifier)"),
                    sourceName: normalized.sourceName,
                    sourceIdentifier: normalized.sourceIdentifier,
                    importedAt: normalized.updatedAt
                )
            ]
        )
    }

    private func fetchPackageResponse() throws -> PackageShowResponse {
        let packageURL = URL(string: "https://data.gov.il/api/3/action/package_show?id=\(BeerShevaDatasetConstants.packageID)")!
        let packageData = try dataLoader.load(from: packageURL)
        return try decoder.decode(PackageShowResponse.self, from: packageData)
    }

    private func findResource(id: String, in resources: [PackageResource]) throws -> PackageResource {
        guard let resource = resources.first(where: { $0.id == id }) else {
            throw DatasetBuilderError.sourceResourceNotFound(
                "Could not find Beer Sheva resource \(id) in package \(BeerShevaDatasetConstants.packageID)."
            )
        }
        return resource
    }

    private func fetchDatastoreRecords<Record: Decodable>(resourceID: String) throws -> [Record] {
        var offset = 0
        var allRecords: [Record] = []

        while true {
            let searchURL = try makeDatastoreSearchURL(resourceID: resourceID, offset: offset, limit: BeerShevaDatasetConstants.datastorePageSize)
            let searchData = try dataLoader.load(from: searchURL)
            let response = try decoder.decode(DatastoreSearchResponse<Record>.self, from: searchData)
            allRecords.append(contentsOf: response.result.records)

            if allRecords.count >= response.result.total || response.result.records.isEmpty {
                break
            }

            offset += BeerShevaDatasetConstants.datastorePageSize
        }

        return allRecords
    }

    private func makeDatastoreSearchURL(resourceID: String, offset: Int, limit: Int) throws -> URL {
        var components = URLComponents(string: "https://data.gov.il/api/3/action/datastore_search")
        components?.queryItems = [
            URLQueryItem(name: "resource_id", value: resourceID),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]

        guard let url = components?.url else {
            throw DatasetBuilderError.invalidArgument("Could not construct datastore search URL for Beer Sheva source.")
        }

        return url
    }

    private func normalizeTimestamp(_ value: String) -> String {
        normalizeTimestampString(value)
    }
}

final class BeerShevaSheltersITMConnector: ExternalSourceConnector {
    private static let resourceID = "6d3e5ce0-b057-4205-92c3-130b05fe69fc"
    private static let sourceName = "beer-sheva-municipal-shelters-itm"

    private let dataLoader: URLDataLoading
    private let decoder = JSONDecoder()
    private let converter = ITM2039ToWGS84Converter()

    init(dataLoader: URLDataLoading) {
        self.dataLoader = dataLoader
    }

    func buildManifest(snapshotURL: URL?) throws -> DatasetBuildManifest {
        let bundle = try loadBundle(snapshotURL: snapshotURL)
        return DatasetBuildManifest(
            datasetVersion: bundle.datasetVersion,
            publishedAt: bundle.publishedAt,
            buildNumber: bundle.buildNumber,
            minimumClientVersion: bundle.minimumClientVersion,
            defaultSourceName: bundle.defaultSourceName,
            places: bundle.normalizedRecords.map(mapToDatasetPlaceRecord),
            reviewReport: nil
        )
    }

    fileprivate func loadBundle(snapshotURL: URL?) throws -> SourceBuildBundle {
        let rawSnapshot = try loadRawSnapshot(snapshotURL: snapshotURL)
        let normalizedRecords = rawSnapshot.records.map { normalize(raw: $0, snapshot: rawSnapshot) }

        return SourceBuildBundle(
            datasetVersion: makeDatasetVersion(prefix: ExternalSourceKind.beerShevaSheltersITM.rawValue, from: rawSnapshot.resourceLastModified),
            publishedAt: rawSnapshot.resourceLastModified,
            buildNumber: 1,
            minimumClientVersion: BeerShevaDatasetConstants.supportedClientVersion,
            defaultSourceName: Self.sourceName,
            normalizedRecords: normalizedRecords
        )
    }

    private func loadRawSnapshot(snapshotURL: URL?) throws -> BeerShevaSheltersITMRawSnapshot {
        if let snapshotURL {
            guard FileManager.default.fileExists(atPath: snapshotURL.path) else {
                throw DatasetBuilderError.sourceSnapshotMissing(snapshotURL.path)
            }

            let data = try Data(contentsOf: snapshotURL)
            let snapshot = try decoder.decode(BeerShevaSheltersITMRawSnapshot.self, from: data)
            return BeerShevaSheltersITMRawSnapshot(
                packageID: snapshot.packageID,
                packageTitle: snapshot.packageTitle,
                packagePageURL: snapshot.packagePageURL,
                resourceID: snapshot.resourceID,
                resourceName: snapshot.resourceName,
                resourceLastModified: normalizeTimestampString(snapshot.resourceLastModified),
                records: snapshot.records,
                fetchedAt: normalizeTimestampString(snapshot.fetchedAt)
            )
        }

        return try fetchLiveRawSnapshot()
    }

    private func fetchLiveRawSnapshot() throws -> BeerShevaSheltersITMRawSnapshot {
        let packageURL = URL(string: "https://data.gov.il/api/3/action/package_show?id=\(BeerShevaDatasetConstants.packageID)")!
        let packageData = try dataLoader.load(from: packageURL)
        let packageResponse = try decoder.decode(PackageShowResponse.self, from: packageData)

        guard let resource = packageResponse.result.resources.first(where: { $0.id == Self.resourceID }) else {
            throw DatasetBuilderError.sourceResourceNotFound(
                "Could not find Beer Sheva ITM resource \(Self.resourceID) in package \(BeerShevaDatasetConstants.packageID)."
            )
        }

        var offset = 0
        var allRecords: [BeerShevaShelterITMRawRecord] = []

        while true {
            let searchURL = try makeDatastoreSearchURL(offset: offset, limit: BeerShevaDatasetConstants.datastorePageSize)
            let searchData = try dataLoader.load(from: searchURL)
            let response = try decoder.decode(DatastoreSearchResponse<BeerShevaShelterITMRawRecord>.self, from: searchData)
            allRecords.append(contentsOf: response.result.records)

            if allRecords.count >= response.result.total || response.result.records.isEmpty {
                break
            }

            offset += BeerShevaDatasetConstants.datastorePageSize
        }

        return BeerShevaSheltersITMRawSnapshot(
            packageID: packageResponse.result.id,
            packageTitle: packageResponse.result.title,
            packagePageURL: BeerShevaDatasetConstants.packagePageURL.absoluteString,
            resourceID: resource.id,
            resourceName: resource.name,
            resourceLastModified: normalizeTimestampString(resource.lastModified),
            records: allRecords,
            fetchedAt: DateCoding.string(from: Date())
        )
    }

    private func makeDatastoreSearchURL(offset: Int, limit: Int) throws -> URL {
        var components = URLComponents(string: "https://data.gov.il/api/3/action/datastore_search")
        components?.queryItems = [
            URLQueryItem(name: "resource_id", value: Self.resourceID),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]

        guard let url = components?.url else {
            throw DatasetBuilderError.invalidArgument("Could not construct datastore search URL for Beer Sheva ITM source.")
        }

        return url
    }

    private func normalize(
        raw: BeerShevaShelterITMRawRecord,
        snapshot: BeerShevaSheltersITMRawSnapshot
    ) -> NormalizedSourcePlaceRecord {
        let trimmedCode = raw.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let sourceIdentifier = "\(snapshot.resourceID):\(raw.rowID)"
        let converted = converter.convert(northing: raw.northing, easting: raw.easting)

        return makeNormalizedRecord(
            stableID: deterministicUUIDString(from: sourceIdentifier),
            sourceName: Self.sourceName,
            sourceIdentifier: sourceIdentifier,
            displayCode: trimmedCode,
            objectLat: converted.latitude,
            objectLon: converted.longitude,
            lastVerifiedAt: snapshot.resourceLastModified,
            createdAt: snapshot.resourceLastModified,
            updatedAt: snapshot.resourceLastModified,
            sourceConfidence: 0.79,
            sourceRoutingQuality: 0.54
        )
    }

    private func mapToDatasetPlaceRecord(_ normalized: NormalizedSourcePlaceRecord) -> DatasetPlaceRecord {
        DatasetPlaceRecord(
            id: normalized.stableID,
            nameOriginal: normalized.nameOriginal,
            nameEn: normalized.nameEn,
            nameRu: normalized.nameRu,
            nameHe: normalized.nameHe,
            addressOriginal: normalized.addressOriginal,
            addressEn: normalized.addressEn,
            addressRu: normalized.addressRu,
            addressHe: normalized.addressHe,
            city: normalized.city,
            placeType: normalized.placeType,
            objectLat: normalized.objectLat,
            objectLon: normalized.objectLon,
            entranceLat: normalized.entranceLat,
            entranceLon: normalized.entranceLon,
            isPublic: normalized.isPublic,
            isAccessible: normalized.isAccessible,
            status: normalized.status,
            confidenceScore: normalized.sourceConfidence,
            routingQuality: normalized.sourceRoutingQuality,
            lastVerifiedAt: normalized.lastVerifiedAt,
            createdAt: normalized.createdAt,
            updatedAt: normalized.updatedAt,
            sourceName: normalized.sourceName,
            sourceIdentifier: normalized.sourceIdentifier,
            routingPoints: normalized.routingPoints.map { routingPoint in
                DatasetRoutingPointRecord(
                    id: routingPoint.id,
                    lat: routingPoint.lat,
                    lon: routingPoint.lon,
                    pointType: routingPoint.pointType,
                    confidence: routingPoint.confidence,
                    derivedFrom: routingPoint.derivedFrom,
                    createdAt: routingPoint.createdAt
                )
            },
            sourceAttributions: [
                DatasetSourceAttributionRecord(
                    id: deterministicUUIDString(from: "\(normalized.stableID)|\(normalized.sourceName)|\(normalized.sourceIdentifier)"),
                    sourceName: normalized.sourceName,
                    sourceIdentifier: normalized.sourceIdentifier,
                    importedAt: normalized.updatedAt
                )
            ]
        )
    }
}

final class BeerShevaCanonicalConnector: ExternalSourceConnector {
    private let wgsConnector: BeerShevaSheltersConnector
    private let itmConnector: BeerShevaSheltersITMConnector
    private let canonicalizer = DedupeV1Canonicalizer()

    init(dataLoader: URLDataLoading) {
        self.wgsConnector = BeerShevaSheltersConnector(dataLoader: dataLoader)
        self.itmConnector = BeerShevaSheltersITMConnector(dataLoader: dataLoader)
    }

    func buildManifest(snapshotURL: URL?) throws -> DatasetBuildManifest {
        let wgsSnapshotURL = try resolveSnapshotURL(
            parentSnapshotURL: snapshotURL,
            expectedFileName: "beer-sheva-shelters-datastore.json"
        )
        let itmSnapshotURL = try resolveSnapshotURL(
            parentSnapshotURL: snapshotURL,
            expectedFileName: "beer-sheva-shelters-itm-datastore.json"
        )

        let wgsBundle = try wgsConnector.loadBundle(snapshotURL: wgsSnapshotURL)
        let itmBundle = try itmConnector.loadBundle(snapshotURL: itmSnapshotURL)
        let publishedAt = [wgsBundle.publishedAt, itmBundle.publishedAt].sorted().last ?? wgsBundle.publishedAt
        let result = canonicalizer.buildCanonicalizationResult(
            records: wgsBundle.normalizedRecords + itmBundle.normalizedRecords,
            generatedAt: publishedAt
        )

        return DatasetBuildManifest(
            datasetVersion: makeDatasetVersion(prefix: ExternalSourceKind.beerShevaCanonicalV1.rawValue, from: publishedAt),
            publishedAt: publishedAt,
            buildNumber: 1,
            minimumClientVersion: BeerShevaDatasetConstants.supportedClientVersion,
            defaultSourceName: ExternalSourceKind.beerShevaCanonicalV1.rawValue,
            places: result.places,
            reviewReport: result.reviewReport
        )
    }

    private func resolveSnapshotURL(parentSnapshotURL: URL?, expectedFileName: String) throws -> URL? {
        guard let parentSnapshotURL else {
            return nil
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: parentSnapshotURL.path, isDirectory: &isDirectory) else {
            throw DatasetBuilderError.sourceSnapshotMissing(parentSnapshotURL.path)
        }

        if isDirectory.boolValue {
            return parentSnapshotURL.appendingPathComponent(expectedFileName)
        }

        throw DatasetBuilderError.invalidArgument(
            "The \(ExternalSourceKind.beerShevaCanonicalV1.rawValue) source expects --source-snapshot to point to a directory containing both raw snapshots."
        )
    }
}

final class PetahTikvaOfficialConnector: ExternalSourceConnector {
    private let dataLoader: URLDataLoading
    private let decoder = JSONDecoder()
    private let canonicalizer = DedupeV1Canonicalizer()
    private let converter = ITM2039ToWGS84Converter()

    init(dataLoader: URLDataLoading) {
        self.dataLoader = dataLoader
    }

    func buildManifest(snapshotURL: URL?) throws -> DatasetBuildManifest {
        let publicBundle = try loadPublicProtectedSpacesBundle()
        let institutionsBundle = try loadInstitutionProtectedSpacesBundle()
        let refugesBundle = try loadRefugesBundle()

        let publishedAt = latestTimestamp([
            publicBundle.publishedAt,
            institutionsBundle.publishedAt,
            refugesBundle.publishedAt
        ])
        let result = canonicalizer.buildCanonicalizationResult(
            records: publicBundle.normalizedRecords + institutionsBundle.normalizedRecords + refugesBundle.normalizedRecords,
            generatedAt: publishedAt
        )

        return DatasetBuildManifest(
            datasetVersion: makeDatasetVersion(prefix: ExternalSourceKind.petahTikvaOfficialV1.rawValue, from: publishedAt),
            publishedAt: publishedAt,
            buildNumber: 1,
            minimumClientVersion: PetahTikvaDatasetConstants.supportedClientVersion,
            defaultSourceName: ExternalSourceKind.petahTikvaOfficialV1.rawValue,
            places: result.places,
            reviewReport: result.reviewReport
        )
    }

    private func loadPublicProtectedSpacesBundle() throws -> SourceBuildBundle {
        let layer = PetahTikvaDatasetConstants.publicLayer
        let metadata = try fetchLayerMetadata(from: layer.dataURL)
        let records: [ArcGISQueryFeature<PetahTikvaProtectedSpaceAttributes>] = try fetchFeatures(
            from: layer.dataURL,
            pageSize: metadata.maxRecordCount ?? 2_000
        )

        return makeBundle(
            source: layer,
            publishedAt: metadata.lastVerifiedAt,
            records: records.compactMap { normalizeProtectedSpaceFeature($0, source: layer, publishedAt: metadata.lastVerifiedAt) }
        )
    }

    private func loadInstitutionProtectedSpacesBundle() throws -> SourceBuildBundle {
        let layer = PetahTikvaDatasetConstants.institutionsLayer
        let metadata = try fetchLayerMetadata(from: layer.dataURL)
        let records: [ArcGISQueryFeature<PetahTikvaProtectedSpaceAttributes>] = try fetchFeatures(
            from: layer.dataURL,
            pageSize: metadata.maxRecordCount ?? 2_000
        )

        return makeBundle(
            source: layer,
            publishedAt: metadata.lastVerifiedAt,
            records: records.compactMap { normalizeProtectedSpaceFeature($0, source: layer, publishedAt: metadata.lastVerifiedAt) }
        )
    }

    private func loadRefugesBundle() throws -> SourceBuildBundle {
        let layer = PetahTikvaDatasetConstants.refugesLayer
        let metadata = try fetchLayerMetadata(from: layer.dataURL)
        let records: [ArcGISQueryFeature<PetahTikvaRefugeAttributes>] = try fetchFeatures(
            from: layer.dataURL,
            pageSize: metadata.maxRecordCount ?? 2_000
        )

        return makeBundle(
            source: layer,
            publishedAt: metadata.lastVerifiedAt,
            records: records.compactMap { normalizeRefugeFeature($0, source: layer, publishedAt: metadata.lastVerifiedAt) }
        )
    }

    private func makeBundle(
        source: ArcGISFeatureLayerSource,
        publishedAt: String,
        records: [NormalizedSourcePlaceRecord]
    ) -> SourceBuildBundle {
        SourceBuildBundle(
            datasetVersion: makeDatasetVersion(prefix: source.sourceName, from: publishedAt),
            publishedAt: publishedAt,
            buildNumber: 1,
            minimumClientVersion: PetahTikvaDatasetConstants.supportedClientVersion,
            defaultSourceName: source.sourceName,
            normalizedRecords: records
        )
    }

    private func normalizeProtectedSpaceFeature(
        _ feature: ArcGISQueryFeature<PetahTikvaProtectedSpaceAttributes>,
        source: ArcGISFeatureLayerSource,
        publishedAt: String
    ) -> NormalizedSourcePlaceRecord? {
        guard let geometry = feature.geometry else {
            return nil
        }

        let converted = converter.convert(northing: geometry.y, easting: geometry.x)
        let attributes = feature.attributes
        let sourceIdentifier = "\(source.sourceLayerName):\(attributes.globalID ?? String(attributes.objectID))"
        let preferredName = firstNonEmpty(
            sanitizedPetahTikvaName(attributes.placeName),
            sanitizedPetahTikvaName(attributes.merhav)
        )
        let nameOriginal = firstNonEmpty(
            preferredName,
            attributes.address
        )
        let addressOriginal = firstNonEmpty(attributes.address)

        return makeMunicipalShelterRecord(
            stableID: deterministicUUIDString(from: sourceIdentifier),
            sourceName: source.sourceName,
            sourceIdentifier: sourceIdentifier,
            city: PetahTikvaDatasetConstants.cityName,
            displayName: nameOriginal ?? addressOriginal ?? source.sourceLayerName,
            nameOriginal: nameOriginal,
            nameHe: nameOriginal,
            addressOriginal: addressOriginal,
            addressHe: addressOriginal,
            objectLat: converted.latitude,
            objectLon: converted.longitude,
            isAccessible: attributes.accessable == 1,
            status: attributes.activated == 0 ? "inactive" : "active",
            lastVerifiedAt: publishedAt,
            createdAt: publishedAt,
            updatedAt: publishedAt,
            sourceConfidence: source.sourceConfidence,
            sourceRoutingQuality: source.sourceRoutingQuality
        )
    }

    private func normalizeRefugeFeature(
        _ feature: ArcGISQueryFeature<PetahTikvaRefugeAttributes>,
        source: ArcGISFeatureLayerSource,
        publishedAt: String
    ) -> NormalizedSourcePlaceRecord? {
        guard let geometry = feature.geometry else {
            return nil
        }

        let converted = converter.convert(northing: geometry.y, easting: geometry.x)
        let attributes = feature.attributes
        let sourceIdentifier = "\(source.sourceLayerName):\(attributes.globalID ?? String(attributes.objectID))"
        let numberLabel = attributes.mikNum.map(String.init)
        let nameOriginal = firstNonEmpty(
            attributes.placeName,
            numberLabel,
            attributes.address
        )
        let addressOriginal = firstNonEmpty(attributes.address)

        return makeMunicipalShelterRecord(
            stableID: deterministicUUIDString(from: sourceIdentifier),
            sourceName: source.sourceName,
            sourceIdentifier: sourceIdentifier,
            city: PetahTikvaDatasetConstants.cityName,
            displayName: nameOriginal ?? addressOriginal ?? source.sourceLayerName,
            nameOriginal: nameOriginal,
            nameHe: nameOriginal,
            addressOriginal: addressOriginal,
            addressHe: addressOriginal,
            objectLat: converted.latitude,
            objectLon: converted.longitude,
            isAccessible: attributes.accessable == 1,
            status: attributes.activated == 0 ? "inactive" : "active",
            lastVerifiedAt: publishedAt,
            createdAt: publishedAt,
            updatedAt: publishedAt,
            sourceConfidence: source.sourceConfidence,
            sourceRoutingQuality: source.sourceRoutingQuality
        )
    }

    private func fetchLayerMetadata(from baseURL: URL) throws -> ArcGISLayerMetadata {
        let data = try dataLoader.load(from: appendQueryItems([URLQueryItem(name: "f", value: "json")], to: baseURL))
        let metadata = try decoder.decode(ArcGISLayerMetadata.self, from: data)

        return ArcGISLayerMetadata(
            name: metadata.name,
            objectIDField: metadata.objectIDField,
            maxRecordCount: metadata.maxRecordCount,
            lastVerifiedAt: metadata.lastVerifiedAt
        )
    }

    private func fetchFeatures<Attributes: Decodable>(
        from baseURL: URL,
        pageSize: Int
    ) throws -> [ArcGISQueryFeature<Attributes>] {
        var offset = 0
        var allFeatures: [ArcGISQueryFeature<Attributes>] = []

        while true {
            let queryURL = baseURL
                .appendingPathComponent("query")
            let data = try dataLoader.load(
                from: appendQueryItems(
                    [
                        URLQueryItem(name: "where", value: "1=1"),
                        URLQueryItem(name: "outFields", value: "*"),
                        URLQueryItem(name: "returnGeometry", value: "true"),
                        URLQueryItem(name: "resultOffset", value: String(offset)),
                        URLQueryItem(name: "resultRecordCount", value: String(pageSize)),
                        URLQueryItem(name: "f", value: "json")
                    ],
                    to: queryURL
                )
            )
            let response = try decoder.decode(ArcGISQueryResponse<Attributes>.self, from: data)
            allFeatures.append(contentsOf: response.features)

            if response.features.count < pageSize {
                break
            }

            offset += response.features.count
        }

        return allFeatures
    }
}

final class TelAvivOfficialConnector: ExternalSourceConnector {
    private let dataLoader: URLDataLoading
    private let decoder = JSONDecoder()
    private let canonicalizer = DedupeV1Canonicalizer()
    private let retryDelaySeconds: TimeInterval = 0.75
    private let maxAttempts = 3

    init(dataLoader: URLDataLoading) {
        self.dataLoader = dataLoader
    }

    func buildManifest(snapshotURL: URL?) throws -> DatasetBuildManifest {
        let bundle = try loadBundle()
        let result = canonicalizer.buildCanonicalizationResult(
            records: bundle.normalizedRecords,
            generatedAt: bundle.publishedAt
        )

        return DatasetBuildManifest(
            datasetVersion: makeDatasetVersion(prefix: ExternalSourceKind.telAvivOfficialV1.rawValue, from: bundle.publishedAt),
            publishedAt: bundle.publishedAt,
            buildNumber: 1,
            minimumClientVersion: TelAvivDatasetConstants.supportedClientVersion,
            defaultSourceName: ExternalSourceKind.telAvivOfficialV1.rawValue,
            places: result.places,
            reviewReport: result.reviewReport
        )
    }

    private func loadBundle() throws -> SourceBuildBundle {
        let layer = TelAvivDatasetConstants.sheltersLayer
        let metadata = try fetchLayerMetadata(from: layer.dataURL)
        let records: [ArcGISQueryFeature<TelAvivShelterAttributes>] = try fetchFeatures(
            from: layer.dataURL,
            pageSize: metadata.maxRecordCount ?? 2_000
        )

        return SourceBuildBundle(
            datasetVersion: makeDatasetVersion(prefix: layer.sourceName, from: metadata.lastVerifiedAt),
            publishedAt: metadata.lastVerifiedAt,
            buildNumber: 1,
            minimumClientVersion: TelAvivDatasetConstants.supportedClientVersion,
            defaultSourceName: layer.sourceName,
            normalizedRecords: records.compactMap { normalizeFeature($0, source: layer, publishedAt: metadata.lastVerifiedAt) }
        )
    }

    private func normalizeFeature(
        _ feature: ArcGISQueryFeature<TelAvivShelterAttributes>,
        source: ArcGISFeatureLayerSource,
        publishedAt: String
    ) -> NormalizedSourcePlaceRecord? {
        let attributes = feature.attributes
        let sourceIdentifier = "\(source.sourceLayerName):\(attributes.uniqueID ?? String(attributes.objectID))"
        guard let coordinate = telAvivCoordinate(for: feature) else {
            return nil
        }

        let addressOriginal = firstNonEmpty(attributes.fullAddress, telAvivAddress(from: attributes))
        let numberLabel = attributes.shelterNumber.map { String($0) }
        let nameOriginal = firstNonEmpty(
            sanitizedMunicipalName(attributes.name),
            addressOriginal,
            numberLabel.map { "Shelter \($0)" }
        )
        let nameHe = firstNonEmpty(
            sanitizedMunicipalName(attributes.name),
            addressOriginal,
            numberLabel.map { "מקלט תל אביב \($0)" }
        )

        return makeMunicipalShelterRecord(
            stableID: deterministicUUIDString(from: sourceIdentifier),
            sourceName: source.sourceName,
            sourceIdentifier: sourceIdentifier,
            city: TelAvivDatasetConstants.cityName,
            displayName: nameOriginal ?? addressOriginal ?? source.sourceLayerName,
            nameOriginal: nameOriginal,
            nameHe: nameHe,
            addressOriginal: addressOriginal,
            addressHe: addressOriginal,
            objectLat: coordinate.latitude,
            objectLon: coordinate.longitude,
            isAccessible: attributes.accessibility == "כן",
            status: telAvivStatus(for: attributes.readiness),
            lastVerifiedAt: publishedAt,
            createdAt: publishedAt,
            updatedAt: publishedAt,
            sourceConfidence: source.sourceConfidence,
            sourceRoutingQuality: source.sourceRoutingQuality
        )
    }

    private func telAvivCoordinate(
        for feature: ArcGISQueryFeature<TelAvivShelterAttributes>
    ) -> (latitude: Double, longitude: Double)? {
        if let latitude = feature.attributes.latitude, let longitude = feature.attributes.longitude {
            return (latitude, longitude)
        }

        if let geometry = feature.geometry {
            let converted = ITM2039ToWGS84Converter().convert(northing: geometry.y, easting: geometry.x)
            return (converted.latitude, converted.longitude)
        }

        return nil
    }

    private func telAvivAddress(from attributes: TelAvivShelterAttributes) -> String? {
        guard let street = firstNonEmpty(attributes.streetName) else {
            return nil
        }

        if let houseNumber = attributes.houseNumber {
            return "\(street) \(houseNumber)"
        }

        return street
    }

    private func telAvivStatus(for readiness: String?) -> String {
        guard let readiness = firstNonEmpty(readiness) else {
            return "unverified"
        }

        if readiness.contains("כשיר") {
            return "active"
        }

        return "unverified"
    }

    private func fetchLayerMetadata(from baseURL: URL) throws -> ArcGISLayerMetadata {
        let data = try loadDataWithRetry(
            from: appendQueryItems([URLQueryItem(name: "f", value: "json")], to: baseURL)
        )
        let metadata = try decoder.decode(ArcGISLayerMetadata.self, from: data)

        return ArcGISLayerMetadata(
            name: metadata.name,
            objectIDField: metadata.objectIDField,
            maxRecordCount: metadata.maxRecordCount,
            lastVerifiedAt: metadata.lastVerifiedAt
        )
    }

    private func fetchFeatures<Attributes: Decodable>(
        from baseURL: URL,
        pageSize: Int
    ) throws -> [ArcGISQueryFeature<Attributes>] {
        for attempt in 1...maxAttempts {
            let allFeatures: [ArcGISQueryFeature<Attributes>] = try fetchFeaturesOnce(
                from: baseURL,
                pageSize: pageSize
            )
            if !allFeatures.isEmpty {
                return allFeatures
            }

            guard attempt < maxAttempts else {
                break
            }

            Thread.sleep(forTimeInterval: retryDelaySeconds)
        }

        throw DatasetBuilderError.invalidArgument("Tel Aviv municipal shelters source returned no records after retry.")
    }

    private func fetchFeaturesOnce<Attributes: Decodable>(
        from baseURL: URL,
        pageSize: Int
    ) throws -> [ArcGISQueryFeature<Attributes>] {
        var offset = 0
        var allFeatures: [ArcGISQueryFeature<Attributes>] = []

        while true {
            let queryURL = baseURL.appendingPathComponent("query")
            let data = try loadDataWithRetry(
                from: appendQueryItems(
                    [
                        URLQueryItem(name: "where", value: "1=1"),
                        URLQueryItem(name: "outFields", value: "*"),
                        URLQueryItem(name: "returnGeometry", value: "true"),
                        URLQueryItem(name: "resultOffset", value: String(offset)),
                        URLQueryItem(name: "resultRecordCount", value: String(pageSize)),
                        URLQueryItem(name: "f", value: "json")
                    ],
                    to: queryURL
                )
            )
            let response = try decoder.decode(ArcGISQueryResponse<Attributes>.self, from: data)
            allFeatures.append(contentsOf: response.features)

            if response.features.count < pageSize {
                break
            }

            offset += response.features.count
        }

        return allFeatures
    }

    private func loadDataWithRetry(from url: URL) throws -> Data {
        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                return try dataLoader.load(from: url)
            } catch {
                lastError = error

                guard attempt < maxAttempts else {
                    break
                }

                Thread.sleep(forTimeInterval: retryDelaySeconds)
            }
        }

        throw lastError ?? DatasetBuilderError.invalidArgument("Failed to load Tel Aviv municipal shelters source.")
    }
}

final class JerusalemOfficialConnector: ExternalSourceConnector {
    private let dataLoader: URLDataLoading
    private let decoder = JSONDecoder()
    private let canonicalizer = DedupeV1Canonicalizer()

    init(dataLoader: URLDataLoading) {
        self.dataLoader = dataLoader
    }

    func buildManifest(snapshotURL: URL?) throws -> DatasetBuildManifest {
        let bundle = try loadBundle()
        let result = canonicalizer.buildCanonicalizationResult(
            records: bundle.normalizedRecords,
            generatedAt: bundle.publishedAt
        )

        return DatasetBuildManifest(
            datasetVersion: makeDatasetVersion(prefix: ExternalSourceKind.jerusalemOfficialV1.rawValue, from: bundle.publishedAt),
            publishedAt: bundle.publishedAt,
            buildNumber: 1,
            minimumClientVersion: JerusalemDatasetConstants.supportedClientVersion,
            defaultSourceName: ExternalSourceKind.jerusalemOfficialV1.rawValue,
            places: result.places,
            reviewReport: result.reviewReport
        )
    }

    private func loadBundle() throws -> SourceBuildBundle {
        let data = try dataLoader.load(from: JerusalemDatasetConstants.geoJSONURL)
        let collection = try decoder.decode(GeoJSONFeatureCollection<JerusalemShelterProperties>.self, from: data)
        let publishedAt = DateCoding.string(from: Date())

        return SourceBuildBundle(
            datasetVersion: makeDatasetVersion(prefix: JerusalemDatasetConstants.sourceName, from: publishedAt),
            publishedAt: publishedAt,
            buildNumber: 1,
            minimumClientVersion: JerusalemDatasetConstants.supportedClientVersion,
            defaultSourceName: JerusalemDatasetConstants.sourceName,
            normalizedRecords: collection.features.compactMap { normalizeFeature($0, publishedAt: publishedAt) }
        )
    }

    private func normalizeFeature(
        _ feature: GeoJSONFeature<JerusalemShelterProperties>,
        publishedAt: String
    ) -> NormalizedSourcePlaceRecord? {
        guard feature.geometry.type == "Point", feature.geometry.coordinates.count >= 2 else {
            return nil
        }

        let longitude = feature.geometry.coordinates[0]
        let latitude = feature.geometry.coordinates[1]
        let shelterNumber = feature.properties.shelterNumber.map { String(Int($0)) } ?? "unknown"
        let objectIdentifier = feature.properties.objectID.map { String(Int($0)) } ?? shelterNumber
        let sourceIdentifier = "jerusalem-public-shelters:\(objectIdentifier)"

        return makeMunicipalShelterRecord(
            stableID: deterministicUUIDString(from: sourceIdentifier),
            sourceName: JerusalemDatasetConstants.sourceName,
            sourceIdentifier: sourceIdentifier,
            city: JerusalemDatasetConstants.cityName,
            displayName: "Public Shelter \(shelterNumber)",
            nameOriginal: "Public Shelter \(shelterNumber)",
            nameHe: "מקלט ציבורי \(shelterNumber)",
            addressOriginal: nil,
            addressHe: nil,
            objectLat: latitude,
            objectLon: longitude,
            isAccessible: false,
            status: "active",
            lastVerifiedAt: publishedAt,
            createdAt: publishedAt,
            updatedAt: publishedAt,
            sourceConfidence: JerusalemDatasetConstants.sourceConfidence,
            sourceRoutingQuality: JerusalemDatasetConstants.sourceRoutingQuality
        )
    }
}

final class MiklatNationalConnector: ExternalSourceConnector {
    private let dataLoader: URLDataLoading
    private let decoder = JSONDecoder()
    private let canonicalizer = DedupeV1Canonicalizer()

    init(dataLoader: URLDataLoading) {
        self.dataLoader = dataLoader
    }

    func buildManifest(snapshotURL: URL?) throws -> DatasetBuildManifest {
        let bundle = try loadBundle()
        let result = canonicalizer.buildCanonicalizationResult(
            records: bundle.normalizedRecords,
            generatedAt: bundle.publishedAt
        )

        return DatasetBuildManifest(
            datasetVersion: makeDatasetVersion(prefix: ExternalSourceKind.miklatNationalV1.rawValue, from: bundle.publishedAt),
            publishedAt: bundle.publishedAt,
            buildNumber: 1,
            minimumClientVersion: MiklatDatasetConstants.supportedClientVersion,
            defaultSourceName: ExternalSourceKind.miklatNationalV1.rawValue,
            places: result.places,
            reviewReport: result.reviewReport
        )
    }

    fileprivate func loadBundle() throws -> SourceBuildBundle {
        let publishedAt = DateCoding.string(from: Date())
        let dataVersion = try fetchDataVersion()
        let cityNameMap = try fetchCityNameMap()
        let liteRecords = try fetchLiteRecords()
        let detailRecords = try fetchDetailRecords()

        let normalizedRecords: [NormalizedSourcePlaceRecord] = liteRecords.enumerated().compactMap { entry in
            let index = entry.offset
            let record = entry.element
            guard let details = detailRecords[String(index)] else {
                return nil
            }

            return normalizeRecord(
                index: index,
                record,
                details: details,
                cityNameMap: cityNameMap,
                dataVersion: dataVersion,
                publishedAt: publishedAt
            )
        }

        return SourceBuildBundle(
            datasetVersion: makeDatasetVersion(prefix: MiklatDatasetConstants.sourceName, from: publishedAt),
            publishedAt: publishedAt,
            buildNumber: 1,
            minimumClientVersion: MiklatDatasetConstants.supportedClientVersion,
            defaultSourceName: MiklatDatasetConstants.sourceName,
            normalizedRecords: normalizedRecords
        )
    }

    private func fetchDataVersion() throws -> String {
        let html = try loadHTML(from: MiklatDatasetConstants.dataVersionURL)
        let pattern = #"dataVersion&quot;:\[0,&quot;([^"]+)&quot;\]"#
        guard let match = html.firstMatch(for: pattern, group: 1) else {
            throw DatasetBuilderError.invalidArgument("Could not read Miklat dataVersion from map page.")
        }
        return match
    }

    private func fetchCityNameMap() throws -> [String: String] {
        let hebrewHTML = try loadHTML(from: MiklatDatasetConstants.hebrewCityIndexURL)
        let englishHTML = try loadHTML(from: MiklatDatasetConstants.englishCityIndexURL)

        let hebrewBySlug = parseCityIndex(html: hebrewHTML)
        let englishBySlug = parseCityIndex(html: englishHTML)

        var map: [String: String] = [:]
        for (slug, hebrewName) in hebrewBySlug {
            guard let englishName = englishBySlug[slug] else {
                continue
            }
            map[hebrewName] = englishName
        }

        return map
    }

    private func fetchLiteRecords() throws -> [MiklatLiteRecord] {
        let data = try dataLoader.load(from: MiklatDatasetConstants.sheltersLiteURL)
        return try decoder.decode([MiklatLiteRecord].self, from: data)
    }

    private func fetchDetailRecords() throws -> [String: MiklatDetailRecord] {
        let data = try dataLoader.load(from: MiklatDatasetConstants.sheltersDetailsURL)
        return try decoder.decode([String: MiklatDetailRecord].self, from: data)
    }

    private func normalizeRecord(
        index: Int,
        _ record: MiklatLiteRecord,
        details: MiklatDetailRecord,
        cityNameMap: [String: String],
        dataVersion: String,
        publishedAt: String
    ) -> NormalizedSourcePlaceRecord? {
        guard let hebrewCity = nonEmpty(details.cityHe),
              let city = cityNameMap[hebrewCity] ?? fallbackEnglishCityName(for: hebrewCity) else {
            return nil
        }

        let sourceIdentifier = "miklat:\(dataVersion):\(index)"
        let addressOriginal = nonEmpty(details.addressHe)
        let nameOriginal = nonEmpty(details.nameHe)
        let addressEn = nonEmpty(details.addressEn)
        let addressRu = nonEmpty(details.addressRu)
        let addressAr = nonEmpty(details.addressAr)

        return NormalizedSourcePlaceRecord(
            stableID: deterministicUUIDString(from: sourceIdentifier),
            sourceName: MiklatDatasetConstants.sourceName,
            sourceIdentifier: sourceIdentifier,
            sourceDisplayName: nameOriginal ?? addressOriginal ?? city,
            city: city,
            normalizedCity: previewCoverageKey(for: city),
            placeType: "public_shelter",
            objectLat: record.latitude,
            objectLon: record.longitude,
            entranceLat: nil,
            entranceLon: nil,
            routingPoints: [],
            nameOriginal: nameOriginal,
            nameEn: nonEmpty(details.nameEn),
            nameRu: nonEmpty(details.nameRu),
            nameHe: nameOriginal,
            addressOriginal: addressOriginal,
            addressEn: addressEn,
            addressRu: addressRu,
            addressHe: addressOriginal,
            normalizedName: normalizedLabel(nameOriginal),
            normalizedAddress: normalizedLabel(addressOriginal ?? addressEn ?? addressRu ?? addressAr),
            isPublic: true,
            isAccessible: details.accessible == 1,
            status: "unverified",
            sourceConfidence: MiklatDatasetConstants.sourceConfidence,
            sourceRoutingQuality: MiklatDatasetConstants.sourceRoutingQuality,
            lastVerifiedAt: nil,
            createdAt: publishedAt,
            updatedAt: publishedAt
        )
    }

    private func loadHTML(from url: URL) throws -> String {
        let data = try dataLoader.load(from: url)
        guard let html = String(data: data, encoding: .utf8) else {
            throw DatasetBuilderError.invalidArgument("Could not decode UTF-8 HTML from \(url.absoluteString).")
        }
        return html
    }

    private func parseCityIndex(html: String) -> [String: String] {
        let pattern = #"<a href="/(?:he|en)/shelters/([^"/]+)/"[^>]*>\s*<div>\s*<h2[^>]*>\s*([^<]+?)\s*</h2>"#
        let matches = html.matches(for: pattern)
        var cities: [String: String] = [:]

        for match in matches {
            guard match.count >= 3 else {
                continue
            }
            let slug = match[1]
            let cityName = match[2].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !slug.isEmpty, !cityName.isEmpty else {
                continue
            }
            cities[slug] = cityName
        }

        return cities
    }

    private func fallbackEnglishCityName(for hebrewCity: String) -> String? {
        switch hebrewCity {
        case "פתח תקווה":
            return "Petah Tikva"
        case "באר שבע":
            return "Beer Sheva"
        case "תל אביב":
            return "Tel Aviv"
        default:
            return nil
        }
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
}

final class IsraelPreviewConnector: ExternalSourceConnector {
    private let beerShevaConnector: BeerShevaCanonicalConnector
    private let petahTikvaConnector: PetahTikvaOfficialConnector
    private let telAvivConnector: TelAvivOfficialConnector
    private let jerusalemConnector: JerusalemOfficialConnector
    private let miklatConnector: MiklatNationalConnector

    init(dataLoader: URLDataLoading) {
        self.beerShevaConnector = BeerShevaCanonicalConnector(dataLoader: dataLoader)
        self.petahTikvaConnector = PetahTikvaOfficialConnector(dataLoader: dataLoader)
        self.telAvivConnector = TelAvivOfficialConnector(dataLoader: dataLoader)
        self.jerusalemConnector = JerusalemOfficialConnector(dataLoader: dataLoader)
        self.miklatConnector = MiklatNationalConnector(dataLoader: dataLoader)
    }

    func buildManifest(snapshotURL: URL?) throws -> DatasetBuildManifest {
        let beerShevaManifest = try beerShevaConnector.buildManifest(snapshotURL: snapshotURL)
        let petahTikvaManifest = try petahTikvaConnector.buildManifest(snapshotURL: snapshotURL)
        let telAvivManifest = try telAvivConnector.buildManifest(snapshotURL: snapshotURL)
        let jerusalemManifest = try jerusalemConnector.buildManifest(snapshotURL: snapshotURL)
        let miklatManifest = try miklatConnector.buildManifest(snapshotURL: snapshotURL)
        let seedManifest = try loadSeedManifest(snapshotURL: snapshotURL)

        let coveredCityKeys = Set(
            [
                BeerShevaDatasetConstants.cityName,
                PetahTikvaDatasetConstants.cityName,
                TelAvivDatasetConstants.cityName,
                JerusalemDatasetConstants.cityName
            ].map(previewCoverageKey)
        )
        let miklatSupplementalPlaces = miklatManifest.places.filter { place in
            guard let city = place.city else {
                return false
            }
            return !coveredCityKeys.contains(previewCoverageKey(for: city))
        }
        let allCoveredCityKeys = coveredCityKeys.union(
            miklatSupplementalPlaces.compactMap { place in
                place.city.map(previewCoverageKey(for:))
            }
        )
        let supplementalPlaces = seedManifest.places.filter { place in
            guard let city = place.city else {
                return true
            }
            return !allCoveredCityKeys.contains(previewCoverageKey(for: city))
        }
        // Preview builds combine mutable municipal sources with a static seed file,
        // so the publication timestamp needs to reflect the build moment to avoid
        // content changes being hidden behind a reused datasetVersion.
        let publishedAt = DateCoding.string(from: Date())
        let minimumClientVersion =
            beerShevaManifest.minimumClientVersion
            ?? petahTikvaManifest.minimumClientVersion
            ?? telAvivManifest.minimumClientVersion
            ?? jerusalemManifest.minimumClientVersion
            ?? miklatManifest.minimumClientVersion
            ?? seedManifest.minimumClientVersion
        let places =
            beerShevaManifest.places
            + petahTikvaManifest.places
            + telAvivManifest.places
            + jerusalemManifest.places
            + miklatSupplementalPlaces
            + supplementalPlaces

        return DatasetBuildManifest(
            datasetVersion: makeDatasetVersion(prefix: ExternalSourceKind.israelPreviewV1.rawValue, from: publishedAt),
            publishedAt: publishedAt,
            buildNumber: 1,
            minimumClientVersion: minimumClientVersion,
            defaultSourceName: ExternalSourceKind.israelPreviewV1.rawValue,
            places: places,
            reviewReport: mergeReviewReports(
                [
                    beerShevaManifest.reviewReport,
                    petahTikvaManifest.reviewReport,
                    telAvivManifest.reviewReport,
                    jerusalemManifest.reviewReport,
                    miklatManifest.reviewReport
                ],
                generatedAt: publishedAt,
                mergedCanonicalCount: places.count
            )
        )
    }

    private func loadSeedManifest(snapshotURL: URL?) throws -> DatasetBuildManifest {
        let inputURL = try resolveSeedInputURL(snapshotURL: snapshotURL)
        guard FileManager.default.fileExists(atPath: inputURL.path) else {
            throw DatasetBuilderError.inputMissing(inputURL.path)
        }

        let inputData = try Data(contentsOf: inputURL)
        let input = try JSONDecoder().decode(CuratedDatasetInput.self, from: inputData)
        return input.makeManifest()
    }

    private func resolveSeedInputURL(snapshotURL: URL?) throws -> URL {
        if let snapshotURL {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: snapshotURL.path, isDirectory: &isDirectory) else {
                throw DatasetBuilderError.sourceSnapshotMissing(snapshotURL.path)
            }

            if isDirectory.boolValue {
                let candidate = snapshotURL.appendingPathComponent(IsraelPreviewDatasetConstants.curatedSeedFileName)
                if FileManager.default.fileExists(atPath: candidate.path) {
                    return candidate
                }
            }
        }

        let currentDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        return currentDirectory.appendingPathComponent("Tools/DatasetBuilder/Input/\(IsraelPreviewDatasetConstants.curatedSeedFileName)")
    }
}

private func makeNormalizedRecord(
    stableID: String,
    sourceName: String,
    sourceIdentifier: String,
    displayCode: String,
    objectLat: Double,
    objectLon: Double,
    lastVerifiedAt: String,
    createdAt: String,
    updatedAt: String,
    sourceConfidence: Double,
    sourceRoutingQuality: Double
) -> NormalizedSourcePlaceRecord {
    let nameOriginal = displayCode
    return NormalizedSourcePlaceRecord(
        stableID: stableID,
        sourceName: sourceName,
        sourceIdentifier: sourceIdentifier,
        sourceDisplayName: displayCode,
        city: BeerShevaDatasetConstants.cityName,
        normalizedCity: normalizedLabel(BeerShevaDatasetConstants.cityName) ?? "beersheva",
        placeType: "public_shelter",
        objectLat: objectLat,
        objectLon: objectLon,
        entranceLat: nil,
        entranceLon: nil,
        routingPoints: [],
        nameOriginal: nameOriginal,
        nameEn: "Beer Sheva Shelter \(displayCode)",
        nameRu: "Укрытие Беэр-Шевы \(displayCode)",
        nameHe: "מקלט באר שבע \(displayCode)",
        addressOriginal: nil,
        addressEn: nil,
        addressRu: nil,
        addressHe: nil,
        normalizedName: normalizedLabel(nameOriginal),
        normalizedAddress: nil,
        isPublic: true,
        isAccessible: false,
        status: "active",
        sourceConfidence: sourceConfidence,
        sourceRoutingQuality: sourceRoutingQuality,
        lastVerifiedAt: lastVerifiedAt,
        createdAt: createdAt,
        updatedAt: updatedAt
    )
}

private func makeMunicipalShelterRecord(
    stableID: String,
    sourceName: String,
    sourceIdentifier: String,
    city: String,
    displayName: String,
    nameOriginal: String?,
    nameHe: String?,
    addressOriginal: String?,
    addressHe: String?,
    objectLat: Double,
    objectLon: Double,
    isAccessible: Bool,
    status: String,
    lastVerifiedAt: String,
    createdAt: String,
    updatedAt: String,
    sourceConfidence: Double,
    sourceRoutingQuality: Double
) -> NormalizedSourcePlaceRecord {
    NormalizedSourcePlaceRecord(
        stableID: stableID,
        sourceName: sourceName,
        sourceIdentifier: sourceIdentifier,
        sourceDisplayName: displayName,
        city: city,
        normalizedCity: normalizedLabel(city) ?? city.lowercased(),
        placeType: "public_shelter",
        objectLat: objectLat,
        objectLon: objectLon,
        entranceLat: nil,
        entranceLon: nil,
        routingPoints: [],
        nameOriginal: nameOriginal,
        nameEn: nil,
        nameRu: nil,
        nameHe: nameHe,
        addressOriginal: addressOriginal,
        addressEn: nil,
        addressRu: nil,
        addressHe: addressHe,
        normalizedName: normalizedLabel(nameOriginal),
        normalizedAddress: normalizedLabel(addressOriginal),
        isPublic: true,
        isAccessible: isAccessible,
        status: status,
        sourceConfidence: sourceConfidence,
        sourceRoutingQuality: sourceRoutingQuality,
        lastVerifiedAt: lastVerifiedAt,
        createdAt: createdAt,
        updatedAt: updatedAt
    )
}

private func mergeReviewReports(
    _ reports: [DedupeReviewReport?],
    generatedAt: String,
    mergedCanonicalCount: Int
) -> DedupeReviewReport? {
    let availableReports = reports.compactMap { $0 }
    guard !availableReports.isEmpty else {
        return nil
    }

    let cases = availableReports
        .flatMap(\.cases)
        .sorted(by: { $0.id < $1.id })
    let mergeRuleVersion = Array(Set(availableReports.map(\.mergeRuleVersion)))
        .sorted()
        .joined(separator: "+")

    return DedupeReviewReport(
        generatedAt: generatedAt,
        mergeRuleVersion: mergeRuleVersion,
        mergedCanonicalCount: mergedCanonicalCount,
        reviewCaseCount: cases.count,
        cases: cases
    )
}

private func previewCoverageKey(for city: String) -> String {
    let normalized = normalizedLabel(city) ?? city.lowercased()

    switch normalized {
    case "beersheva", "בארשבע":
        return "beersheva"
    case "petahtikva", "פתחתקווה":
        return "petahtikva"
    case "telaviv", "telavivyafo", "תלאביב":
        return "telaviv"
    case "rishonlezion", "ראשוןלציון":
        return "rishonlezion"
    default:
        return normalized
    }
}

private struct MiklatLiteRecord: Decodable {
    let longitude: Double
    let latitude: Double
    let type: Int

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        longitude = try container.decode(Double.self)
        latitude = try container.decode(Double.self)
        type = try container.decode(Int.self)
    }
}

private struct MiklatDetailRecord: Decodable {
    let addressHe: String?
    let cityHe: String?
    let nameHe: String?
    let addressEn: String?
    let addressRu: String?
    let addressAr: String?
    let nameEn: String?
    let nameRu: String?
    let accessible: Int?
    let source: String?

    enum CodingKeys: String, CodingKey {
        case addressHe = "a"
        case cityHe = "c"
        case nameHe = "n"
        case addressEn = "ae"
        case addressRu = "ra"
        case addressAr = "aa"
        case nameEn = "ne"
        case nameRu = "nr"
        case accessible = "acc"
        case source = "src"
    }
}

private extension String {
    func firstMatch(for pattern: String, group: Int) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let nsRange = NSRange(startIndex..<endIndex, in: self)
        guard let match = regex.firstMatch(in: self, range: nsRange),
              match.numberOfRanges > group,
              let range = Range(match.range(at: group), in: self) else {
            return nil
        }
        return String(self[range])
    }

    func matches(for pattern: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }
        let nsRange = NSRange(startIndex..<endIndex, in: self)
        return regex.matches(in: self, range: nsRange).map { match in
            (0..<match.numberOfRanges).compactMap { index in
                guard let range = Range(match.range(at: index), in: self) else {
                    return nil
                }
                return String(self[range])
            }
        }
    }
}

private func sanitizedPetahTikvaName(_ value: String?) -> String? {
    guard let normalized = firstNonEmpty(value) else {
        return nil
    }

    let scalarSet = CharacterSet.decimalDigits
        .union(.whitespacesAndNewlines)
        .union(CharacterSet(charactersIn: "/-"))

    let isOnlyNumericMarker = normalized.unicodeScalars.allSatisfy { scalarSet.contains($0) }
    return isOnlyNumericMarker ? nil : normalized
}

private func sanitizedMunicipalName(_ value: String?) -> String? {
    guard let normalized = firstNonEmpty(value) else {
        return nil
    }

    if normalized == "-" || normalized == "." {
        return nil
    }

    return normalized
}

private func firstNonEmpty(_ values: String?...) -> String? {
    values.compactMap { value -> String? in
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }.first
}

private func appendQueryItems(_ items: [URLQueryItem], to url: URL) -> URL {
    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
        return url
    }

    components.queryItems = (components.queryItems ?? []) + items
    return components.url ?? url
}

private func makeDatasetVersion(prefix: String, from resourceLastModified: String) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"

    if let date = DateCoding.date(from: resourceLastModified) {
        return "\(prefix)-\(formatter.string(from: date))"
    }

    let sanitized = resourceLastModified.replacingOccurrences(of: ":", with: "-")
    return "\(prefix)-\(sanitized)"
}

private func latestTimestamp(_ values: [String]) -> String {
    let datedValues = values.compactMap { value -> (Date, String)? in
        guard let date = DateCoding.date(from: value) else {
            return nil
        }
        return (date, value)
    }

    if let latest = datedValues.max(by: { $0.0 < $1.0 }) {
        return latest.1
    }

    return values.sorted().last ?? DateCoding.string(from: Date())
}

private func normalizeTimestampString(_ value: String) -> String {
    if DateCoding.date(from: value) != nil {
        return value
    }

    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"

    if let date = formatter.date(from: value) {
        return DateCoding.string(from: date)
    }

    return value
}

struct BeerShevaSheltersRawSnapshot: Codable {
    let packageID: String
    let packageTitle: String
    let packagePageURL: String
    let resourceID: String
    let resourceName: String
    let resourceLastModified: String
    let records: [BeerShevaShelterRawRecord]
    let fetchedAt: String
}

struct BeerShevaShelterRawRecord: Codable {
    let rowID: Int
    let name: String
    let latitude: Double
    let longitude: Double

    enum CodingKeys: String, CodingKey {
        case rowID = "_id"
        case name
        case latitude = "lat"
        case longitude = "lon"
    }
}

struct BeerShevaSheltersITMRawSnapshot: Codable {
    let packageID: String
    let packageTitle: String
    let packagePageURL: String
    let resourceID: String
    let resourceName: String
    let resourceLastModified: String
    let records: [BeerShevaShelterITMRawRecord]
    let fetchedAt: String
}

struct BeerShevaShelterITMRawRecord: Codable {
    let rowID: Int
    let name: String
    let northing: Double
    let easting: Double

    enum CodingKeys: String, CodingKey {
        case rowID = "_id"
        case name
        case northing = "lat"
        case easting = "lon"
    }
}

private struct PackageShowResponse: Decodable {
    let result: PackageShowResult
}

private struct PackageShowResult: Decodable {
    let id: String
    let title: String
    let resources: [PackageResource]
}

private struct PackageResource: Decodable {
    let id: String
    let name: String
    let lastModified: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case lastModified = "last_modified"
    }
}

private struct DatastoreSearchResponse<Record: Decodable>: Decodable {
    let result: DatastoreSearchResult<Record>
}

private struct DatastoreSearchResult<Record: Decodable>: Decodable {
    let total: Int
    let records: [Record]
}

private struct ArcGISFeatureLayerSource {
    let sourceName: String
    let sourceLayerName: String
    let dataURL: URL
    let sourceConfidence: Double
    let sourceRoutingQuality: Double
}

private struct ArcGISLayerMetadata: Decodable {
    let name: String
    let objectIDField: String?
    let maxRecordCount: Int?
    let lastVerifiedAt: String

    private let editingInfo: ArcGISEditingInfo?

    enum CodingKeys: String, CodingKey {
        case name
        case objectIDField = "objectIdField"
        case maxRecordCount
        case editingInfo
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        objectIDField = try container.decodeIfPresent(String.self, forKey: .objectIDField)
        maxRecordCount = try container.decodeIfPresent(Int.self, forKey: .maxRecordCount)
        editingInfo = try container.decodeIfPresent(ArcGISEditingInfo.self, forKey: .editingInfo)
        lastVerifiedAt = editingInfo?.lastEditDate.flatMap { timestamp in
            DateCoding.string(from: Date(timeIntervalSince1970: Double(timestamp) / 1000))
        } ?? DateCoding.string(from: Date())
    }

    init(name: String, objectIDField: String?, maxRecordCount: Int?, lastVerifiedAt: String) {
        self.name = name
        self.objectIDField = objectIDField
        self.maxRecordCount = maxRecordCount
        self.lastVerifiedAt = lastVerifiedAt
        self.editingInfo = nil
    }
}

private struct ArcGISEditingInfo: Decodable {
    let lastEditDate: Int64?
}

private struct ArcGISQueryResponse<Attributes: Decodable>: Decodable {
    let features: [ArcGISQueryFeature<Attributes>]
}

private struct ArcGISQueryFeature<Attributes: Decodable>: Decodable {
    let attributes: Attributes
    let geometry: ArcGISPointGeometry?
}

private struct ArcGISPointGeometry: Decodable {
    let x: Double
    let y: Double
}

private struct PetahTikvaProtectedSpaceAttributes: Decodable {
    let objectID: Int
    let merhav: String?
    let address: String?
    let numbermik: String?
    let placeName: String?
    let activated: Int?
    let accessable: Int?
    let globalID: String?

    enum CodingKeys: String, CodingKey {
        case objectID = "OBJECTID"
        case merhav = "MERHAV"
        case address = "Address"
        case numbermik = "numbermik"
        case placeName = "PlaceName"
        case activated = "Activated"
        case accessable = "Accessable"
        case globalID = "GlobalID"
    }
}

private struct PetahTikvaRefugeAttributes: Decodable {
    let objectID: Int
    let mikNum: Int?
    let address: String?
    let placeName: String?
    let activated: Int?
    let accessable: Int?
    let globalID: String?

    enum CodingKeys: String, CodingKey {
        case objectID = "OBJECTID"
        case mikNum = "MikNum"
        case address = "Address"
        case placeName = "PlaceName"
        case activated = "Activated"
        case accessable = "Accessable"
        case globalID = "GlobalID"
    }
}

private struct TelAvivShelterAttributes: Decodable {
    let objectID: Int
    let shelterNumber: Int?
    let streetName: String?
    let houseNumber: Int?
    let fullAddress: String?
    let latitude: Double?
    let longitude: Double?
    let name: String?
    let readiness: String?
    let uniqueID: String?
    let accessibility: String?

    enum CodingKeys: String, CodingKey {
        case objectID = "oid_mitkan"
        case shelterNumber = "ms_miklat"
        case streetName = "shem_recho"
        case houseNumber = "ms_bait"
        case fullAddress = "Full_Address"
        case latitude = "lat"
        case longitude = "lon"
        case name = "shem"
        case readiness = "pail"
        case uniqueID = "UniqueId"
        case accessibility = "miklat_mungash"
    }
}

private struct GeoJSONFeatureCollection<Properties: Decodable>: Decodable {
    let features: [GeoJSONFeature<Properties>]
}

private struct GeoJSONFeature<Properties: Decodable>: Decodable {
    let properties: Properties
    let geometry: GeoJSONPointGeometry
}

private struct GeoJSONPointGeometry: Decodable {
    let type: String
    let coordinates: [Double]
}

private struct JerusalemShelterProperties: Decodable {
    let objectID: Double?
    let shelterNumber: Double?

    enum CodingKeys: String, CodingKey {
        case objectID = "OBJECTID"
        case shelterNumber = "מספר מקלט"
    }
}
