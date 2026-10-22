// CampPlace.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import CoreLocation

/// A name to suggest for a new camp and the zone its evenings and pack-by are counted in.
struct CampPlace: Sendable {
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

    /// The whole-hour offset of the longitude's band, right at sea and close enough on land
    /// for choosing which evening to fetch.
    static func estimatedZone(longitude: Double) -> TimeZone {
        TimeZone(secondsFromGMT: Int((longitude / 15).rounded()) * 3600) ?? .gmt
    }
}
