import Foundation

struct RoutingDestination: Identifiable, Hashable, Sendable {
    let provider: RoutingAppProvider
    let primaryURL: URL
    let fallbackURL: URL?
    let isPreferred: Bool

    var id: RoutingAppProvider { provider }
}
