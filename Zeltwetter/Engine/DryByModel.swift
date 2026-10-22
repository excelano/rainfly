// DryByModel.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// A heuristic for when a tent wet with dew or frost is dry enough to pack: the fly starts
/// drying in the first hour after sunrise with a wide spread and either sun or a breeze.
struct DryByModel: Codable, Equatable, Sendable {
    var minSpreadC = 5.0
    var maxCloudCover = 0.7
    var minWindMS = 2.0
    var dryingTime: TimeInterval = 60 * 60
    var frostExtra: TimeInterval = 30 * 60
    /// The local hour after which the estimate gives up.
    var cutoffHour = 12

    func dryBy(_ night: NightForecast, frost: Bool, calendar: Calendar) -> Date? {
        guard let cutoff = calendar.date(bySettingHour: cutoffHour, minute: 0, second: 0, of: night.sunrise) else {
            return nil
        }
        let drying = night.hours
            .sorted { $0.date < $1.date }
            .first { hour in
                hour.date.addingTimeInterval(3600) > night.sunrise
                    && hour.date < cutoff
                    && dries(hour)
            }
        guard let drying else { return nil }
        let start = max(drying.date, night.sunrise)
        return start.addingTimeInterval(dryingTime + (frost ? frostExtra : 0))
    }

    private func dries(_ hour: HourSample) -> Bool {
        hour.spreadC >= minSpreadC && (hour.cloudCover < maxCloudCover || hour.windMS >= minWindMS)
    }
}
