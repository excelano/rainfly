// NightWindow.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// A forecast's hours split into the night and the morning after it. An hour belongs to
/// the night when it overlaps sunset to sunrise, so the hour holding sunset counts, and to
/// the morning when it overlaps sunrise to pack-by, so the hour holding sunrise counts for both.
struct NightWindow: Sendable {
    let calendar: Calendar
    let sunset: Date
    let sunrise: Date
    let packBy: Date
    let nightHours: [HourSample]
    let morningHours: [HourSample]

    init(_ night: NightForecast, packByMinutes: Int) {
        let calendar = Self.localCalendar(for: night.location)
        self.calendar = calendar
        sunset = night.sunset
        sunrise = night.sunrise
        packBy = calendar.date(
            bySettingHour: packByMinutes / 60, minute: packByMinutes % 60, second: 0, of: night.sunrise
        ) ?? night.sunrise
        let hours = night.hours.sorted { $0.date < $1.date }
        nightHours = hours.filter { $0.date.addingTimeInterval(3600) > night.sunset && $0.date < night.sunrise }
        morningHours = hours.filter { [packBy] in $0.date.addingTimeInterval(3600) > night.sunrise && $0.date < packBy }
    }

    var low: Double? { nightHours.map(\.tempC).min() }
    var closestSpread: Double? { nightHours.map(\.spreadC).min() }
    /// Across the morning too, since rain before pack-by matters as much.
    var maxPrecipChance: Double? { (nightHours + morningHours).map(\.precipChance).max() }

    static func localCalendar(for camp: CampLocation) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = camp.timeZone
        return calendar
    }
}
