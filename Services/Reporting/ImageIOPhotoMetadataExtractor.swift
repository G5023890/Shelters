import Foundation
import ImageIO

enum PhotoMetadataExtractionError: LocalizedError {
    case unsupportedFile

    var errorDescription: String? {
        switch self {
        case .unsupportedFile:
            return "The selected file does not contain readable image metadata."
        }
    }
}

struct ImageIOPhotoMetadataExtractor: PhotoMetadataExtracting {
    func extractMetadata(from fileURL: URL) async throws -> ExtractedPhotoMetadata {
        try fileURL.withSecurityScopedAccess {
            guard
                let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
                let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
            else {
                throw PhotoMetadataExtractionError.unsupportedFile
            }

            return ExtractedPhotoMetadata(
                exifCoordinate: extractCoordinate(from: properties),
                capturedAt: extractCapturedAt(from: properties)
            )
        }
    }

    private func extractCoordinate(from properties: [String: Any]) -> GeoCoordinate? {
        guard let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] else {
            return nil
        }

        guard
            let rawLatitude = gps[kCGImagePropertyGPSLatitude as String] as? Double,
            let rawLongitude = gps[kCGImagePropertyGPSLongitude as String] as? Double
        else {
            return nil
        }

        let latitudeRef = (gps[kCGImagePropertyGPSLatitudeRef as String] as? String)?.uppercased() ?? "N"
        let longitudeRef = (gps[kCGImagePropertyGPSLongitudeRef as String] as? String)?.uppercased() ?? "E"

        let latitude = latitudeRef == "S" ? -rawLatitude : rawLatitude
        let longitude = longitudeRef == "W" ? -rawLongitude : rawLongitude

        return GeoCoordinate(latitude: latitude, longitude: longitude)
    }

    private func extractCapturedAt(from properties: [String: Any]) -> Date? {
        let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any]
        let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any]

        let values = [
            exif?[kCGImagePropertyExifDateTimeOriginal as String] as? String,
            exif?[kCGImagePropertyExifDateTimeDigitized as String] as? String,
            tiff?[kCGImagePropertyTIFFDateTime as String] as? String
        ]

        for value in values {
            if let value, let date = Self.exifDateFormatter.date(from: value) {
                return date
            }
        }

        return nil
    }

    private static let exifDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter
    }()
}
