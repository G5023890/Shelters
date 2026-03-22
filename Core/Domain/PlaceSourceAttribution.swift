import Foundation

struct PlaceSourceAttribution: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let canonicalPlaceID: UUID
    let sourceName: String
    let sourceIdentifier: String?
    let importedAt: Date
}
