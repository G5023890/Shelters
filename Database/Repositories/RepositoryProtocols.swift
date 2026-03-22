import Foundation

protocol CanonicalPlaceRepository: Sendable {
    func upsert(_ places: [CanonicalPlace]) throws
    func fetchAll(limit: Int?) throws -> [CanonicalPlace]
    func fetch(id: UUID) throws -> CanonicalPlace?
    func fetchNearbyCandidates(around coordinate: GeoCoordinate, radiusMeters: Double, limit: Int) throws -> [CanonicalPlace]
    func count() throws -> Int
}

protocol RoutingPointRepository: Sendable {
    func replaceRoutingPoints(_ routingPoints: [RoutingPoint], for placeID: UUID) throws
    func fetchRoutingPoints(for placeID: UUID) throws -> [RoutingPoint]
}

protocol SourceAttributionRepository: Sendable {
    func fetchSourceAttributions(for placeID: UUID) throws -> [PlaceSourceAttribution]
}

protocol UserReportRepository: Sendable {
    func save(_ report: UserReport) throws
    func fetchPendingReports() throws -> [UserReport]
    func fetchAll(limit: Int?) throws -> [UserReport]
    func fetch(id: UUID) throws -> UserReport?
}

protocol PhotoEvidenceRepository: Sendable {
    func save(_ photoEvidence: PhotoEvidence) throws
    func fetchPhotoEvidence(for reportID: UUID) throws -> [PhotoEvidence]
    func fetch(id: UUID) throws -> PhotoEvidence?
}

protocol PendingUploadRepository: Sendable {
    func save(_ item: PendingUploadItem) throws
    func fetchPendingUploads() throws -> [PendingUploadItem]
    func fetchUploads(for reportID: UUID) throws -> [PendingUploadItem]
    func fetch(id: UUID) throws -> PendingUploadItem?
    func fetch(entityType: PendingUploadEntityType, entityID: String) throws -> PendingUploadItem?
}

protocol SyncMetadataRepository: Sendable {
    func value(for key: String) throws -> String?
    func setValue(_ value: String, for key: String) throws
    func fetchAll() throws -> [SyncMetadata]
}

protocol AppSettingsRepository: Sendable {
    func value(for key: String) throws -> String?
    func setValue(_ value: String, for key: String) throws
}
