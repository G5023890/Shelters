import CoreLocation
import Foundation

enum AppleLocationServiceError: LocalizedError {
    case managerUnavailable
    case requestAlreadyInProgress
    case unableToDetermineLocation
    case underlying(String)

    var errorDescription: String? {
        switch self {
        case .managerUnavailable:
            return "Location services are unavailable on this device."
        case .requestAlreadyInProgress:
            return "A location request is already in progress."
        case .unableToDetermineLocation:
            return "Current location could not be determined."
        case .underlying(let message):
            return message
        }
    }
}

@MainActor
final class AppleLocationService: NSObject, LocationService, CLLocationManagerDelegate {
    private let manager: CLLocationManager
    private var authorizationContinuation: CheckedContinuation<LocationAuthorizationStatus, Never>?
    private var locationContinuation: CheckedContinuation<LocationSnapshot?, Error>?
    private var streamingContinuation: AsyncThrowingStream<LocationSnapshot, Error>.Continuation?

    override init() {
        self.manager = CLLocationManager()
        super.init()
        self.manager.delegate = self
        self.manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func authorizationStatus() async -> LocationAuthorizationStatus {
        Self.mapAuthorization(manager.authorizationStatus)
    }

    func requestPermission() async -> LocationAuthorizationStatus {
        guard CLLocationManager.locationServicesEnabled() else {
            return .restricted
        }

        let currentStatus = Self.mapAuthorization(manager.authorizationStatus)
        guard currentStatus == .notDetermined else {
            return currentStatus
        }

        return await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    func currentLocation() async throws -> LocationSnapshot? {
        guard CLLocationManager.locationServicesEnabled() else {
            throw AppleLocationServiceError.managerUnavailable
        }

        let status = await authorizationStatus()

        switch status {
        case .denied, .restricted:
            return nil
        case .notDetermined:
            let updatedStatus = await requestPermission()
            guard updatedStatus == .authorized else { return nil }
        case .authorized:
            break
        }

        if let existingLocation = manager.location, abs(existingLocation.timestamp.timeIntervalSinceNow) < 30 {
            return Self.makeSnapshot(from: existingLocation)
        }

        guard locationContinuation == nil else {
            throw AppleLocationServiceError.requestAlreadyInProgress
        }

        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    func locationUpdates() -> AsyncThrowingStream<LocationSnapshot, Error> {
        AsyncThrowingStream { continuation in
            if let existingContinuation = streamingContinuation {
                existingContinuation.finish()
            }

            streamingContinuation = continuation

            if let existingLocation = manager.location {
                continuation.yield(Self.makeSnapshot(from: existingLocation))
            }

            manager.startUpdatingLocation()

            continuation.onTermination = { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.streamingContinuation = nil
                    self.manager.stopUpdatingLocation()
                }
            }
        }
    }

    nonisolated private static func mapAuthorization(_ status: CLAuthorizationStatus) -> LocationAuthorizationStatus {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .restricted
        }
    }

    nonisolated private static func makeSnapshot(from location: CLLocation) -> LocationSnapshot {
        LocationSnapshot(
            coordinate: GeoCoordinate(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            ),
            timestamp: location.timestamp
        )
    }
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = Self.mapAuthorization(manager.authorizationStatus)

        Task { @MainActor in
            guard let authorizationContinuation else { return }
            self.authorizationContinuation = nil
            authorizationContinuation.resume(returning: status)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let snapshot = locations.last.map(Self.makeSnapshot(from:))

        Task { @MainActor in
            if let snapshot {
                streamingContinuation?.yield(snapshot)
            }

            guard let locationContinuation else { return }
            self.locationContinuation = nil
            locationContinuation.resume(returning: snapshot)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let isLocationUnknown = (error as? CLError)?.code == .locationUnknown
        let errorDescription = error.localizedDescription

        Task { @MainActor in
            if !isLocationUnknown {
                streamingContinuation?.finish(throwing: AppleLocationServiceError.underlying(errorDescription))
                streamingContinuation = nil
                self.manager.stopUpdatingLocation()
            }

            guard let locationContinuation else { return }
            self.locationContinuation = nil

            if isLocationUnknown {
                locationContinuation.resume(returning: nil)
                return
            }

            locationContinuation.resume(throwing: AppleLocationServiceError.underlying(errorDescription))
        }
    }
}
