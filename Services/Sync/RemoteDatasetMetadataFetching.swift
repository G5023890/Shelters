import Foundation

protocol RemoteDatasetMetadataFetching: Sendable {
    func fetchLatestVersionResponse() async throws -> DatasetVersionResponseDTO
}

struct MissingRemoteDatasetMetadataSource: RemoteDatasetMetadataFetching {
    func fetchLatestVersionResponse() async throws -> DatasetVersionResponseDTO {
        throw SyncExecutionError.metadataEndpointNotConfigured
    }
}

enum RemoteDatasetMetadataSourceError: LocalizedError {
    case requestFailed
    case invalidResponseStatus(Int)
    case unsupportedResponse

    var errorDescription: String? {
        switch self {
        case .requestFailed:
            return "Remote metadata request could not be completed."
        case .invalidResponseStatus(let statusCode):
            return "Remote metadata request failed with status \(statusCode)."
        case .unsupportedResponse:
            return "Remote metadata endpoint returned an unsupported response."
        }
    }
}
