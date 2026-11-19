// NightRecord.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// When a fetch made after sunrise has settled into WeatherKit's record of the night.
enum NightRecord {
    static func isSettled(_ night: NightForecast) -> Bool {
        night.fetchedAt >= ready(night)
    }

    static func ready(_ night: NightForecast) -> Date {
        night.sunrise.addingTimeInterval(delay)
    }

    /// How long after sunrise WeatherKit's hours for the night are taken as its record.
    static let delay: TimeInterval = 2 * 3600
}
