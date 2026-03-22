import SwiftUI

struct PhotoEvidenceRow: View {
    let photo: PhotoEvidence

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(URL(fileURLWithPath: photo.localFilePath).lastPathComponent)
                .font(.headline)

            if let capturedAt = photo.capturedAt {
                Text("\(L10n.string(.reportingPhotoCapturedAt)): \(DateCoding.string(from: capturedAt))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let exifCoordinate = photo.exifCoordinate {
                Text("\(L10n.string(.reportingPhotoCoordinates)): \(exifCoordinate.formattedString())")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text(L10n.text(.reportingPhotoMetadataMissing))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let checksum = photo.checksum, !checksum.isEmpty {
                Text("\(L10n.string(.reportingPhotoChecksum)): \(checksum)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.vertical, 4)
    }
}
