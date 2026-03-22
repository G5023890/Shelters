import Foundation

struct AppSettingsSnapshot: Hashable, Sendable {
    var preferredRoutingProvider: RoutingAppProvider
    var languageOverride: AppLanguage?
}

