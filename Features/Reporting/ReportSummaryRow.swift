import SwiftUI

struct ReportSummaryRow: View {
    let report: UserReport

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Label(
                    title: {
                        Text(L10n.text(report.reportType.localizationKey))
                            .font(.headline)
                    },
                    icon: {
                        Image(systemName: report.reportType.systemImageName)
                            .foregroundStyle(Color.accentColor)
                    }
                )

                Spacer()

                Text(L10n.text(report.reportStatus.localizationKey))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if let note = report.textNote, !note.isEmpty {
                Text(note)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack {
                Text(DateCoding.string(from: report.localCreatedAt))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let userCoordinate = report.userCoordinate {
                    Spacer()
                    Text(userCoordinate.formattedString())
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let lastError = report.lastError, !lastError.isEmpty {
                Text(lastError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}
