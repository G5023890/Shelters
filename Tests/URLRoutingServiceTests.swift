import Foundation
import XCTest
@testable import SheltersKit

final class URLRoutingServiceTests: XCTestCase {
    func testPreferredProviderIsFirstInRoutingDestinations() {
        let destinations = URLRoutingService().destinations(
            for: makeTarget(),
            preferredProvider: .waze
        )

        XCTAssertEqual(destinations.map(\.provider), [.waze, .appleMaps, .googleMaps])
        XCTAssertEqual(destinations.first?.isPreferred, true)
    }

    func testAppleMapsDestinationUsesNativeMapsURL() {
        let destination = URLRoutingService().destination(
            for: makeTarget(),
            using: .appleMaps,
            preferredProvider: .appleMaps
        )

        XCTAssertEqual(destination?.primaryURL.host, "maps.apple.com")
        XCTAssertNil(destination?.fallbackURL)
    }

    func testGoogleMapsDestinationIncludesWebFallback() {
        let destination = URLRoutingService().destination(
            for: makeTarget(),
            using: .googleMaps,
            preferredProvider: .appleMaps
        )

        XCTAssertEqual(destination?.primaryURL.scheme, "comgooglemaps")
        XCTAssertEqual(destination?.fallbackURL?.host, "www.google.com")
        XCTAssertTrue(destination?.fallbackURL?.absoluteString.contains("travelmode=walking") == true)
    }

    func testWazeDestinationIncludesWebFallback() {
        let destination = URLRoutingService().destination(
            for: makeTarget(),
            using: .waze,
            preferredProvider: .appleMaps
        )

        XCTAssertEqual(destination?.primaryURL.scheme, "waze")
        XCTAssertEqual(destination?.fallbackURL?.host, "www.waze.com")
        XCTAssertTrue(destination?.fallbackURL?.absoluteString.contains("navigate=yes") == true)
    }

    private func makeTarget() -> ResolvedRoutingTarget {
        ResolvedRoutingTarget(
            coordinate: GeoCoordinate(latitude: 32.0853, longitude: 34.7818),
            pointType: .entrance,
            source: .placeEntrance
        )
    }
}
