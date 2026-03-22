import SwiftUI

struct NearbyPlaceCard: View {
    let place: CanonicalPlace
    let routingTarget: ResolvedRoutingTarget
    let distanceMeters: Double?
    let walkingMinutes: Int?
    let language: AppLanguage
    let rankingScore: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(place.displayName(for: language))
                    .font(.headline)
                    .foregroundStyle(.primary)

                if let city = place.city, !city.isEmpty {
                    Text(city)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                let address = place.displayAddress(for: language)
                if !address.isEmpty {
                    Text(address)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                NearbyBadge(text: L10n.string(place.placeType.localizationKey), systemImage: "building.2")

                if let distanceMeters {
                    NearbyBadge(
                        text: L10n.formatDistance(distanceMeters),
                        systemImage: "point.bottomleft.forward.to.point.topright.scurvepath"
                    )
                }

                if let walkingMinutes {
                    NearbyBadge(
                        text: String(format: L10n.string(.nearbyWalkingMinutesFormat), walkingMinutes),
                        systemImage: "figure.walk"
                    )
                }

                NearbyBadge(
                    text: L10n.string(routingTarget.source.localizationKey),
                    systemImage: "arrow.turn.up.right"
                )

                if place.isPublic {
                    NearbyBadge(text: L10n.string(.metadataPublicAccess), systemImage: "person.2")
                }

                if place.isAccessible {
                    NearbyBadge(text: L10n.string(.metadataAccessibility), systemImage: "figure.roll")
                }
            }

            HStack(spacing: 12) {
                Text(L10n.text(place.status.localizationKey))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(place.status == .active ? .green : .secondary)

                Spacer()

                if let rankingScore {
                    Text(String(format: "%.2f", rankingScore))
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
    }
}

private struct NearbyBadge: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.secondary.opacity(0.12))
            )
    }
}

private struct FlowLayout: Layout {
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    init(horizontalSpacing: CGFloat, verticalSpacing: CGFloat) {
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += rowHeight + verticalSpacing
                rowHeight = 0
            }

            currentX += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: maxWidth, height: currentY + rowHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += rowHeight + verticalSpacing
                rowHeight = 0
            }

            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            currentX += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

