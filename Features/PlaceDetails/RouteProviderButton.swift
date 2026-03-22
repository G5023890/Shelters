import SwiftUI

struct RouteProviderButton: View {
    enum Emphasis {
        case primary
        case secondary
    }

    let destination: RoutingDestination
    let action: () -> Void
    let emphasis: Emphasis

    @ViewBuilder
    var body: some View {
        switch emphasis {
        case .primary:
            baseButton
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        case .secondary:
            baseButton
                .buttonStyle(.bordered)
        }
    }

    private var baseButton: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Label(
                    L10n.formatted(.placeDetailsOpenInFormat, L10n.string(destination.provider.localizationKey)),
                    systemImage: destination.provider.systemImageName
                )
                Spacer()
                if destination.isPreferred {
                    Text(L10n.text(.commonPreferred))
                        .font(.caption.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
