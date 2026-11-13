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
    /// When the night's forecast is fixed for judging it in the morning: 22:00 on the
    /// evening, or sunset where the sun sets later.
    let anchor: Date
    /// Noon after the night, when the morning gives way to the next night's forecast.
    let handover: Date
    let nightHours: [HourSample]
    let morningHours: [HourSample]

    init(_ night: NightForecast, packByMinutes: Int, from start: Date = .distantPast) {
        let calendar = Self.localCalendar(for: night.location)
        self.calendar = calendar
        sunset = night.sunset
        sunrise = night.sunrise
        packBy = calendar.date(
            bySettingHour: packByMinutes / 60, minute: packByMinutes % 60, second: 0, of: night.sunrise
        ) ?? night.sunrise
        anchor = Self.anchor(of: night)
        handover = calendar.date(bySettingHour: Self.handoverHour, minute: 0, second: 0, of: night.sunrise) ?? night.sunrise
        let hours = night.hours.sorted { $0.date < $1.date }.filter { $0.date.addingTimeInterval(3600) > start }
        let nightEnd = min(night.sunrise, packBy)
        nightHours = hours.filter { $0.date.addingTimeInterval(3600) > night.sunset && $0.date < nightEnd }
        morningHours = hours.filter { [packBy] in $0.date.addingTimeInterval(3600) > night.sunrise && $0.date < packBy }
    }

    enum Phase: Equatable, Sendable {
        /// Up to 22:00: deciding whether the rainfly goes on.
        case evening
        /// 22:00 to sunrise: watching for changes.
        case overnight
        /// Sunrise to noon: how the night went, and packing up.
        case morning
    }

    func phase(at now: Date) -> Phase {
        now < anchor ? .evening : now < sunrise ? .overnight : .morning
    }

    static func anchor(of night: NightForecast) -> Date {
        let calendar = localCalendar(for: night.location)
        let evening = night.sunset.addingTimeInterval(-12 * 3600)
        let ten = calendar.date(bySettingHour: anchorHour, minute: 0, second: 0, of: evening) ?? night.sunset
        return max(ten, night.sunset)
    }

    /// Of the forecasts fetched for one night, the one it is judged against: the last fetched
    /// by its anchor, or the first when none was.
    static func decided(_ fetches: [NightForecast]) -> NightForecast? {
        let sorted = fetches.sorted { $0.fetchedAt < $1.fetchedAt }
        guard let first = sorted.first else { return nil }
        return sorted.last { $0.fetchedAt <= anchor(of: first) } ?? first
    }

    static func decidedAt(_ decided: NightForecast) -> Date {
        max(decided.fetchedAt, anchor(of: decided))
    }

    /// The last forecast fetched before sunrise, which shows how the forecast moved overnight.
    static func beforeMorning(_ fetches: [NightForecast]) -> NightForecast? {
        fetches.filter(\.fetchedBeforeSunrise).max { $0.fetchedAt < $1.fetchedAt }
    }

    static let anchorHour = 22
    static let handoverHour = 12

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
