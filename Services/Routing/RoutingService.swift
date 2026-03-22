import Foundation

protocol RoutingService: Sendable {
    func destination(
        for target: ResolvedRoutingTarget,
        using provider: RoutingAppProvider,
        preferredProvider: RoutingAppProvider
    ) -> RoutingDestination?
}

extension RoutingService {
    func destinations(
        for target: ResolvedRoutingTarget,
        preferredProvider: RoutingAppProvider
    ) -> [RoutingDestination] {
        let providerOrder = Dictionary(
            uniqueKeysWithValues: RoutingAppProvider.allCases.enumerated().map { ($1, $0) }
        )

        return RoutingAppProvider.allCases
            .compactMap { destination(for: target, using: $0, preferredProvider: preferredProvider) }
            .sorted { lhs, rhs in
                if lhs.isPreferred != rhs.isPreferred {
                    return lhs.isPreferred
                }

                return (providerOrder[lhs.provider] ?? .max) < (providerOrder[rhs.provider] ?? .max)
            }
    }

    func preferredDestination(
        for target: ResolvedRoutingTarget,
        preferredProvider: RoutingAppProvider
    ) -> RoutingDestination? {
        destinations(for: target, preferredProvider: preferredProvider).first
    }
}
