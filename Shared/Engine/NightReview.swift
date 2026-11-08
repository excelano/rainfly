// NightReview.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// Why dew or frost did not form over a night's hours: the one condition that was missing.
enum SpreadMiss: Equatable, Sendable {
    /// The air never got close enough to its dew point; the closest gap it reached.
    case tooDry(closestC: Double)
    case cloudy, windy, cloudyOrWindy
    /// Clear and calm with the gap reached, but on the other side of the frost line.
    case otherSideOfFrostLine

    /// Nil when the night has no hours or the check would fire.
    static func of(_ trigger: Trigger, hours: [HourSample], settings: Settings) -> SpreadMiss? {
        guard let closest = hours.map(\.spreadC).min() else { return nil }
        let close = hours.filter { $0.spreadC <= settings.dewSpreadC }
        guard !close.isEmpty else { return .tooDry(closestC: closest) }
        let isCloudy = { (hour: HourSample) in hour.cloudCover >= settings.clearSky }
        let isWindy = { (hour: HourSample) in hour.windMS >= settings.calmWindMS }
        let open = close.filter { !isCloudy($0) && !isWindy($0) }
        if !open.isEmpty {
            let rightSide = open.contains { FlyEngine.isFrostAir($0.tempC) == (trigger == .frost) }
            return rightSide ? nil : .otherSideOfFrostLine
        }
        switch (close.contains(where: isCloudy), close.contains(where: isWindy)) {
        case (true, false): return .cloudy
        case (false, true): return .windy
        default: return .cloudyOrWindy
        }
    }
}

/// How the forecast a night was judged against compares with Apple Weather's record of it,
/// check by check.
struct NightReview: Sendable {
    struct Check: Equatable, Sendable {
        let trigger: Trigger
        let expected: Firing?
        let happened: Firing?
        var isRight: Bool { (expected != nil) == (happened != nil) }
    }

    let decided: NightForecast
    let record: NightForecast
    let checks: [Check]

    /// The checks either side fired, and rain always, since it is the one most people ask about.
    init(decided: NightForecast, record: NightForecast, settings: Settings) {
        self.decided = decided
        self.record = record
        let expected = FlyEngine.evaluate(decided, settings: settings)
        checks = Trigger.allCases.compactMap { trigger in
            let check = Check(
                trigger: trigger, expected: expected.firing(trigger),
                happened: Self.happened(trigger, in: record, settings: settings)
            )
            return check.expected != nil || check.happened != nil || trigger == .rain ? check : nil
        }
    }

    /// What the record shows for a check. Rain counts only where it fell, since a past hour's
    /// chance of rain says nothing.
    static func happened(_ trigger: Trigger, in record: NightForecast, settings: Settings) -> Firing? {
        let window = NightWindow(record, packByMinutes: settings.packByMinutes)
        let first = { (hours: [HourSample], when: (HourSample) -> Bool) in
            hours.first(where: when).map { Firing(trigger: trigger, at: $0.date) }
        }
        switch trigger {
        case .storm: return first(window.nightHours + window.morningHours) { $0.isThunderstorm }
        case .rain: return first(window.nightHours) { $0.precipAmountMM > 0 }
        case .morningRain: return first(window.morningHours) { $0.precipAmountMM > 0 }
        case .windRain:
            return first(window.nightHours) { max($0.windMS, $0.gustMS ?? 0) > settings.windRainMS && $0.precipAmountMM > 0 }
        case .dew, .frost, .cold: return FlyEngine.evaluate(record, settings: settings).firing(trigger)
        }
    }

    /// Whether a fetch made after sunrise has settled into WeatherKit's record of the night.
    static func isRecord(_ night: NightForecast) -> Bool {
        night.fetchedAt >= recordReady(night)
    }

    static func recordReady(_ night: NightForecast) -> Date {
        night.sunrise.addingTimeInterval(recordDelay)
    }

    /// How long after sunrise WeatherKit's hours for the night are taken as its record.
    static let recordDelay: TimeInterval = 2 * 3600
}
