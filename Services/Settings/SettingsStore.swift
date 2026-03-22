import Foundation
import SwiftUI

@MainActor
final class SettingsStore: ObservableObject {
    @Published private(set) var preferredRoutingProvider: RoutingAppProvider = .appleMaps
    @Published private(set) var languageOverride: AppLanguage?

    private let service: AppSettingsService
    private let systemFallbackLanguage: AppLanguage

    init(service: AppSettingsService, systemLocale: Locale = .current) {
        self.service = service
        self.systemFallbackLanguage = AppLanguage.resolve(from: systemLocale)
    }

    var activeLanguage: AppLanguage {
        languageOverride ?? systemFallbackLanguage
    }

    func load() async {
        do {
            let settings = try await service.loadSettings()
            preferredRoutingProvider = settings.preferredRoutingProvider
            languageOverride = settings.languageOverride
        } catch {
            // TODO: surface settings loading failures in a debug diagnostics flow.
        }
    }

    func updatePreferredRoutingProvider(_ provider: RoutingAppProvider) {
        preferredRoutingProvider = provider

        Task {
            try? await service.setPreferredRoutingProvider(provider)
        }
    }

    func updateLanguageOverride(_ language: AppLanguage?) {
        languageOverride = language

        Task {
            try? await service.setLanguageOverride(language)
        }
    }
}

