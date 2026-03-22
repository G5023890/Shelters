import Foundation
import OSLog

struct URLSessionRemoteDatasetMetadataSource: RemoteDatasetMetadataFetching {
    private static let logger = Logger(subsystem: "com.grigorymordokhovich.Shelters", category: "DatasetSync")

    let endpoint: URL
    var session: URLSession = .shared

    func fetchLatestVersionResponse() async throws -> DatasetVersionResponseDTO {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(from: endpoint)
        } catch {
            Self.logger.error("Metadata fetch failed for \(endpoint.absoluteString): \(error.localizedDescription)")
            throw RemoteDatasetMetadataSourceError.requestFailed
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RemoteDatasetMetadataSourceError.unsupportedResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            Self.logger.error("Metadata fetch returned status \(httpResponse.statusCode) for \(endpoint.absoluteString)")
            throw RemoteDatasetMetadataSourceError.invalidResponseStatus(httpResponse.statusCode)
        }

        do {
            return try SyncCoding.decoder().decode(DatasetVersionResponseDTO.self, from: data)
        } catch {
            Self.logger.error("Metadata decoding failed for \(endpoint.absoluteString): \(error.localizedDescription)")
            throw SyncExecutionError.metadataDecodingFailed
        }
    }
}
