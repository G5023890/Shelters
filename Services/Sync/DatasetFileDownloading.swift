import Foundation

struct DownloadedDatasetFile: Hashable, Sendable {
    let fileURL: URL
    let suggestedFilename: String?
    let expectedContentLength: Int64?
}

protocol DatasetFileDownloading: Sendable {
    func download(from remoteURL: URL) async throws -> DownloadedDatasetFile
}

enum DatasetFileDownloadError: LocalizedError {
    case requestFailed
    case invalidResponseStatus(Int)
    case unsupportedResponse
    case failedToMoveDownloadedFile

    var errorDescription: String? {
        switch self {
        case .requestFailed:
            return "Dataset download could not be completed."
        case .invalidResponseStatus(let statusCode):
            return "Dataset download failed with status \(statusCode)."
        case .unsupportedResponse:
            return "Dataset download returned an unsupported response."
        case .failedToMoveDownloadedFile:
            return "Downloaded dataset could not be staged in temporary storage."
        }
    }
}
