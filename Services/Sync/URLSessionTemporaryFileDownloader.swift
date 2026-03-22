import Foundation
import OSLog

struct URLSessionTemporaryFileDownloader: DatasetFileDownloading {
    private static let logger = Logger(subsystem: "com.grigorymordokhovich.Shelters", category: "DatasetSync")

    var session: URLSession = .shared

    func download(from remoteURL: URL) async throws -> DownloadedDatasetFile {
        let (temporaryURL, response): (URL, URLResponse)
        do {
            (temporaryURL, response) = try await session.download(from: remoteURL)
        } catch {
            Self.logger.error("Dataset download failed for \(remoteURL.absoluteString): \(error.localizedDescription)")
            throw DatasetFileDownloadError.requestFailed
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DatasetFileDownloadError.unsupportedResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            Self.logger.error("Dataset download returned status \(httpResponse.statusCode) for \(remoteURL.absoluteString)")
            throw DatasetFileDownloadError.invalidResponseStatus(httpResponse.statusCode)
        }

        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory.appendingPathComponent("SheltersSync", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let filename = response.suggestedFilename ?? "dataset-\(UUID().uuidString).sqlite"
        let destinationURL = directory.appendingPathComponent("\(UUID().uuidString)-\(filename)")

        do {
            try fileManager.moveItem(at: temporaryURL, to: destinationURL)
        } catch {
            Self.logger.error("Failed to stage downloaded dataset for \(remoteURL.absoluteString): \(error.localizedDescription)")
            throw DatasetFileDownloadError.failedToMoveDownloadedFile
        }

        return DownloadedDatasetFile(
            fileURL: destinationURL,
            suggestedFilename: response.suggestedFilename,
            expectedContentLength: response.expectedContentLength > 0 ? response.expectedContentLength : nil
        )
    }
}
