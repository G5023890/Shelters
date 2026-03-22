import Foundation

final class DefaultAppSettingsService: AppSettingsService {
    private enum Keys {
        static let preferredRoutingProvider = "preferred_routing_provider"
        static let languageOverride = "language_override"
    }

    private let repository: AppSettingsRepository

    init(repository: AppSettingsRepository) {
        self.repository = repository
    }

    func loadSettings() async throws -> AppSettingsSnapshot {
        let preferredRoutingProvider = try repository.value(for: Keys.preferredRoutingProvider)
            .flatMap(RoutingAppProvider.init(rawValue:))
            ?? .appleMaps

        let languageOverride = try repository.value(for: Keys.languageOverride)
            .flatMap { $0.isEmpty ? nil : $0 }
            .flatMap(AppLanguage.init(rawValue:))

        return AppSettingsSnapshot(
            preferredRoutingProvider: preferredRoutingProvider,
            languageOverride: languageOverride
        )
    }

    func setPreferredRoutingProvider(_ provider: RoutingAppProvider) async throws {
        try repository.setValue(provider.rawValue, for: Keys.preferredRoutingProvider)
    }

    func setLanguageOverride(_ language: AppLanguage?) async throws {
        try repository.setValue(language?.rawValue ?? "", for: Keys.languageOverride)
    }
}

