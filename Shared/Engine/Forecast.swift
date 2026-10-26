// Forecast.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

struct CampLocation: Codable, Equatable, Sendable {
    /// The camp that follows the watch's own position.
    static let hereName = "Here"

    let name: String
    let latitude: Double
    let longitude: Double
    /// The camp's own zone, so pack-by and noon are local to the camp rather than the watch.
    let timeZoneID: String

    var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }
}

/// One forecast hour, starting at `date`.
struct HourSample: Codable, Equatable, Sendable {
    let date: Date
    let tempC: Double
    let dewPointC: Double
    let humidity: Double          // 0...1
    let cloudCover: Double        // 0...1
    let windMS: Double
    let gustMS: Double?
    let precipChance: Double      // 0...1
    let precipAmountMM: Double
    let isThunderstorm: Bool

    var spreadC: Double { tempC - dewPointC }
}

struct NightForecast: Codable, Equatable, Sendable {
    let location: CampLocation
    let fetchedAt: Date
    let sunset: Date
    /// The sunrise that ends this night, on the following morning.
    let sunrise: Date
    let hours: [HourSample]
}
