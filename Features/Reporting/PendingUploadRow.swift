import SwiftUI

struct PendingUploadRow: View {
    let item: PendingUploadItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(L10n.text(item.entityType.localizationKey))
                    .font(.headline)
                Spacer()
                Text(L10n.text(item.uploadState.localizationKey))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(DateCoding.string(from: item.updatedAt))
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack {
                Text("\(L10n.string(.reportingUploadAttempts)): \(item.attemptCount)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let lastAttemptAt = item.lastAttemptAt {
                    Spacer()
                    Text(DateCoding.string(from: lastAttemptAt))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let lastError = item.lastError, !lastError.isEmpty {
                Text(lastError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }
}
