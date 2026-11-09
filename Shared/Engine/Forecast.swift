// Forecast.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

struct CampLocation: Codable, Equatable, Sendable {
    /// The camp that follows the watch's own position.
    static let hereName = "Here"
    static let hereTitle = "My Location"

    static func title(_ name: String) -> String {
        name == hereName ? hereTitle : name
    }

    var title: String { Self.title(name) }

    let name: String
    let latitude: Double
    let longitude: Double
    /// The camp's own zone, so pack-by and noon are local to the camp rather than the watch.
    let timeZoneID: String

    var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }
}

/// Apple Weather's estimate of the weather at a camp right now.
struct CurrentConditions: Codable, Equatable, Sendable {
    let date: Date
    let tempC: Double
    let dewPointC: Double
    let cloudCover: Double
    let windMS: Double
    let isRaining: Bool

    var spreadC: Double { tempC - dewPointC }
}

/// One forecast hour, starting at `date`.
struct HourSample: Codable, Equatable, Sendable {
    let date: Date
    let tempC: Double
    let dewPointC: Double
    let humidity: Double          // 0...1
    let cloudCover: Double        // 0...1
    /// Nil before iOS 18 and watchOS 11, which first report it, and in hours saved without it.
    var cloudLayers: CloudLayers? = nil
    let windMS: Double
    let gustMS: Double?
    let precipChance: Double      // 0...1
    let precipAmountMM: Double
    let isThunderstorm: Bool

    var spreadC: Double { tempC - dewPointC }
}

/// The share of the sky covered at each height, each 0...1. Low cloud holds the night's
/// warmth in; thin high cloud barely does.
struct CloudLayers: Codable, Equatable, Sendable {
    let low: Double
    let medium: Double
    let high: Double
}

struct NightForecast: Codable, Equatable, Sendable {
    let location: CampLocation
    let fetchedAt: Date
    let sunset: Date
    /// The sunrise that ends this night, on the following morning.
    let sunrise: Date
    let hours: [HourSample]
    /// Set where the sun stays up or stays down, when sunset and sunrise are 9 PM and 6 AM.
    var polar: PolarSky? = nil
}
