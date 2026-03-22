import Foundation

final class AppSupportPhotoEvidenceFileStore: @unchecked Sendable, PhotoEvidenceFileStoring {
    private let fileManager: FileManager
    private let destinationDirectoryURL: URL

    init(
        destinationDirectoryURL: URL,
        fileManager: FileManager = .default
    ) {
        self.destinationDirectoryURL = destinationDirectoryURL
        self.fileManager = fileManager
    }

    func storePhoto(from originalFileURL: URL) throws -> URL {
        try fileManager.createDirectory(at: destinationDirectoryURL, withIntermediateDirectories: true)

        let storedFileURL = destinationDirectoryURL.appendingPathComponent(
            "\(UUID().uuidString).\(originalFileURL.pathExtension.ifEmpty("jpg"))"
        )

        try originalFileURL.withSecurityScopedAccess {
            if fileManager.fileExists(atPath: storedFileURL.path) {
                try fileManager.removeItem(at: storedFileURL)
            }

            try fileManager.copyItem(at: originalFileURL, to: storedFileURL)
        }

        return storedFileURL
    }
}

private extension String {
    func ifEmpty(_ fallback: @autoclosure () -> String) -> String {
        isEmpty ? fallback() : self
    }
}
