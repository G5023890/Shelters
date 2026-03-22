import Foundation

struct DatasetVersionInfo: Hashable, Codable, Sendable {
    let datasetVersion: String
    let publishedAt: Date
    let buildNumber: Int
    let checksum: String
    let downloadURL: URL
    let schemaVersion: Int
    let minimumClientVersion: String?
    let fileSize: Int?
    let recordCount: Int?
}
