import Foundation

struct DatasetVersionResponseDTO: Decodable, Sendable {
    let datasetVersion: String
    let publishedAt: Date
    let buildNumber: Int
    let checksum: String
    let downloadURL: URL
    let schemaVersion: Int
    let minimumClientVersion: String?
    let fileSize: Int?
    let recordCount: Int?

    func makeDomainModel() -> DatasetVersionInfo {
        DatasetVersionInfo(
            datasetVersion: datasetVersion,
            publishedAt: publishedAt,
            buildNumber: buildNumber,
            checksum: checksum,
            downloadURL: downloadURL,
            schemaVersion: schemaVersion,
            minimumClientVersion: minimumClientVersion,
            fileSize: fileSize,
            recordCount: recordCount
        )
    }
}
