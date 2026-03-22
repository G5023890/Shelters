import Foundation

enum RoutingAppProvider: String, CaseIterable, Codable, Sendable, Identifiable {
    case appleMaps = "apple_maps"
    case googleMaps = "google_maps"
    case waze

    var id: String { rawValue }

    var systemImageName: String {
        switch self {
        case .appleMaps:
            return "map.fill"
        case .googleMaps:
            return "location.fill"
        case .waze:
            return "car.fill"
        }
    }

    var localizationKey: L10n.Key {
        switch self {
        case .appleMaps:
            return .routingProviderAppleMaps
        case .googleMaps:
            return .routingProviderGoogleMaps
        case .waze:
            return .routingProviderWaze
        }
    }
}
