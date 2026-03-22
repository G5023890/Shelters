import Foundation

protocol AppSettingsService: Sendable {
    func loadSettings() async throws -> AppSettingsSnapshot
    func setPreferredRoutingProvider(_ provider: RoutingAppProvider) async throws
    func setLanguageOverride(_ language: AppLanguage?) async throws
}

