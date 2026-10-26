// CampPlace.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import CoreLocation
import MapKit

/// A name to suggest for a new camp and the zone its evenings and pack-by are counted in.
struct CampPlace: Hashable, Sendable {
    let name: String?
    let timeZone: TimeZone

    /// Asks Apple's map service about the point. Offline, there is no name and the zone is
    /// estimated from the longitude.
    static func lookUp(latitude: Double, longitude: Double) async -> CampPlace {
        let placemark = try? await CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: latitude, longitude: longitude)).first
        return CampPlace(
            name: placemark.flatMap { $0.areasOfInterest?.first ?? $0.locality ?? $0.name },
            timeZone: placemark?.timeZone ?? estimatedZone(longitude: longitude)
        )
    }

    /// Places matching `query`, favouring those near `near` when it is given.
    @MainActor
    static func search(_ query: String, near: Point?) async throws -> [FoundPlace] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.pointOfInterest, .address]
        if let near {
            let center = CLLocationCoordinate2D(latitude: near.latitude, longitude: near.longitude)
            request.region = MKCoordinateRegion(center: center, latitudinalMeters: 300_000, longitudinalMeters: 300_000)
        }
        let items = try await MKLocalSearch(request: request).start().mapItems
        return items.map { item in
            let placemark = item.placemark
            let coordinate = placemark.coordinate
            return FoundPlace(
                point: Point(latitude: coordinate.latitude, longitude: coordinate.longitude),
                place: CampPlace(
                    name: item.name,
                    timeZone: item.timeZone ?? estimatedZone(longitude: coordinate.longitude)
                ),
                detail: [placemark.locality, placemark.administrativeArea, placemark.countryCode]
                    .compactMap { $0 }.joined(separator: ", ")
            )
        }
    }

    /// The whole-hour offset of the longitude's band, right at sea and close enough on land
    /// for choosing which evening to fetch.
    static func estimatedZone(longitude: Double) -> TimeZone {
        TimeZone(secondsFromGMT: Int((longitude / 15).rounded()) * 3600) ?? .gmt
    }
}

struct FoundPlace: Hashable, Sendable {
    let point: Point
    let place: CampPlace
    let detail: String
}

struct Point: Hashable, Sendable {
    let latitude: Double
    let longitude: Double
}
