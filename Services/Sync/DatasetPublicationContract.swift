import Foundation

enum DatasetPublicationContract {
    static let metadataFilename = "dataset-metadata.json"
    static let snapshotFilename = "shelters.sqlite"

    static let requiredMetadataFields = [
        "datasetVersion",
        "publishedAt",
        "schemaVersion",
        "checksum",
        "downloadURL",
        "recordCount",
        "buildNumber"
    ]

    static let optionalMetadataFields = [
        "minimumClientVersion",
        "fileSize"
    ]

    static let localDevelopmentMetadataURL = URL(string: "http://127.0.0.1:8000/dataset-metadata.json")!
}
