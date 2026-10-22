// LocationFix.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import CoreLocation

/// One coarse position for the forecast, asking for permission the first time.
@MainActor
final class LocationFix: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func current() async throws -> CLLocation {
        guard continuation == nil else { throw ForecastError.noLocation }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            proceed(manager.authorizationStatus)
        }
    }

    private func proceed(_ status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            finish(.failure(ForecastError.noLocation))
        }
    }

    private func finish(_ result: Result<CLLocation, Error>) {
        continuation?.resume(with: result)
        continuation = nil
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        MainActor.assumeIsolated {
            if continuation != nil, status != .notDetermined { proceed(status) }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        MainActor.assumeIsolated { finish(.success(latest)) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated { finish(.failure(ForecastError.noLocation)) }
    }
}
