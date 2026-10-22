// NightWindow.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// A forecast's hours split into the night and the morning after it. An hour belongs to
/// the night when it overlaps sunset to sunrise, so the hour holding sunset counts, and to
/// the morning when it starts between sunrise and pack-by.
struct NightWindow: Sendable {
    let calendar: Calendar
    let packBy: Date
    let nightHours: [HourSample]
    let morningHours: [HourSample]

    init(_ night: NightForecast, packByMinutes: Int) {
        let calendar = Self.localCalendar(for: night.location)
        self.calendar = calendar
        packBy = calendar.date(
            bySettingHour: packByMinutes / 60, minute: packByMinutes % 60, second: 0, of: night.sunrise
        ) ?? night.sunrise
        let hours = night.hours.sorted { $0.date < $1.date }
        nightHours = hours.filter { $0.date.addingTimeInterval(3600) > night.sunset && $0.date < night.sunrise }
        morningHours = hours.filter { [packBy] in $0.date >= night.sunrise && $0.date < packBy }
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

    /// The start of the day whose evening begins the night that matters at `now`: last
    /// night until pack-by, tonight from then on.
    static func evening(at now: Date, packByMinutes: Int, calendar: Calendar) -> Date {
        let today = calendar.startOfDay(for: now)
        let packBy = calendar.date(bySettingHour: packByMinutes / 60, minute: packByMinutes % 60, second: 0, of: now) ?? today
        return now < packBy ? calendar.date(byAdding: .day, value: -1, to: today) ?? today : today
    }
}
