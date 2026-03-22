import Foundation

struct URLRoutingService: RoutingService {
    func destination(
        for target: ResolvedRoutingTarget,
        using provider: RoutingAppProvider,
        preferredProvider: RoutingAppProvider
    ) -> RoutingDestination? {
        let latitude = coordinateString(target.coordinate.latitude)
        let longitude = coordinateString(target.coordinate.longitude)
        let primaryURL: URL?
        let fallbackURL: URL?

        switch provider {
        case .appleMaps:
            primaryURL = URL(string: "http://maps.apple.com/?daddr=\(latitude),\(longitude)&dirflg=w")
            fallbackURL = nil
        case .googleMaps:
            primaryURL = URL(string: "comgooglemaps://?daddr=\(latitude),\(longitude)&directionsmode=walking")
            fallbackURL = URL(
                string: "https://www.google.com/maps/dir/?api=1&destination=\(latitude),\(longitude)&travelmode=walking"
            )
        case .waze:
            primaryURL = URL(string: "waze://?ll=\(latitude),\(longitude)&navigate=yes")
            fallbackURL = URL(string: "https://www.waze.com/ul?ll=\(latitude),\(longitude)&navigate=yes")
        }

        guard let primaryURL else {
            return nil
        }

        return RoutingDestination(
            provider: provider,
            primaryURL: primaryURL,
            fallbackURL: fallbackURL,
            isPreferred: provider == preferredProvider
        )
    }

    private func coordinateString(_ value: Double) -> String {
        String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}
