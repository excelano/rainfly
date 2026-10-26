// SharedHours.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// A night's forecast or history without its camp.
struct SharedHours: Codable, Equatable {
    let fetchedAt: Date
    let sunset: Date
    let sunrise: Date
    let hours: [HourSample]

    init(_ night: NightForecast) {
        fetchedAt = night.fetchedAt
        sunset = night.sunset
        sunrise = night.sunrise
        hours = night.hours
    }
}

extension SharedHours {
    /// The night again, at a camp with no name, for the engine.
    func night(latitude: Double, longitude: Double, timeZoneID: String) -> NightForecast {
        NightForecast(
            location: CampLocation(name: "", latitude: latitude, longitude: longitude, timeZoneID: timeZoneID),
            fetchedAt: fetchedAt, sunset: sunset, sunrise: sunrise, hours: hours
        )
    }
}
