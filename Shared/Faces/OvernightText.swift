// OvernightText.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// The words for the night after 22:00: the latest verdict, what has changed since the forecast
/// the night is judged against, and the weather right now.
struct OvernightText {
    /// The latest forecast.
    let text: VerdictText
    /// The forecast the night is judged against, fixed at 22:00.
    let decided: NightForecast

    private var decidedVerdict: Verdict { FlyEngine.evaluate(decided, settings: text.settings) }

    private var decidedAt: String {
        text.clock(max(decided.fetchedAt, NightWindow.anchor(of: decided)))
    }

    /// "Overnight · updated 02:10".
    var caption: String { "Overnight · updated \(text.clock(text.night.fetchedAt))" }

    private var added: Firing? {
        text.verdict.firings.first { decidedVerdict.firing($0.trigger) == nil }
    }

    private var dropped: Firing? {
        decidedVerdict.firings.first { text.verdict.firing($0.trigger) == nil }
    }

    var hasChanged: Bool { added != nil || dropped != nil }

    /// What is new since 22:00, or the verdict's own reason when nothing is.
    var reason: String {
        if let added { return "New since \(decidedAt): \(Self.lowered(text.describe(added)))" }
        if let dropped { return "No longer expected since \(decidedAt): \(VerdictText.name(dropped.trigger).lowercased())" }
        return text.reason
    }

    /// What Rainfly said at 22:00 when the forecast has moved, or that it hasn't.
    var note: String {
        guard hasChanged else { return "Same as the \(decidedAt) forecast" }
        let said = "At \(decidedAt), Rainfly said \(decidedVerdict.flyOn ? "on" : "off")"
        return decidedVerdict.headline.map { "\(said): \(Self.lowered(text.describe($0)))" } ?? said
    }

    /// For the inline complication: "New: rain 05:00".
    var brief: String? {
        added.map { "New: \(Self.lowered(text.brief($0)))" }
    }

    /// The forecast hours from `now` to sunrise, at most eight.
    func hoursAhead(at now: Date) -> [HourSample] {
        Array(text.night.hours
            .sorted { $0.date < $1.date }
            .filter { $0.date.addingTimeInterval(3600) > now && $0.date < text.night.sunrise }
            .prefix(8))
    }

    /// The hour's label in the row of hours: "03".
    func hourLabel(_ hour: HourSample) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = text.night.location.timeZone
        let value = calendar.component(.hour, from: hour.date)
        switch text.locale.hourCycle {
        case .oneToTwelve, .zeroToEleven: return "\(value % 12 == 0 ? 12 : value % 12)\(value < 12 ? "a" : "p")"
        default: return String(format: "%02d", value)
        }
    }

    /// What the weather is doing right now, in a title and a sentence.
    func now(_ current: CurrentConditions) -> (title: String, detail: String) {
        let settings = text.settings
        if current.isRaining { return ("It's raining", "Apple Weather shows rain here right now.") }
        let gap = text.spread(current.spreadC)
        guard current.spreadC <= settings.dewSpreadC else {
            return ("Dry right now", "The air is \(gap) from its dew point.")
        }
        let cloudy = current.cloudCover >= settings.clearSky, windy = current.windMS >= settings.calmWindMS
        if !cloudy && !windy {
            let wet = FlyEngine.isFrostAir(current.tempC) ? "Frost" : "Dew"
            return ("\(wet) is forming", "The air is only \(gap) from its dew point, the sky is clear and there's almost no wind.")
        }
        let blocker = cloudy && windy ? "clouds and wind keep" : cloudy ? "clouds keep" : "wind keeps"
        return ("Damp, but no dew yet", "The air is \(gap) from its dew point, but the \(blocker) the tent from cooling down.")
    }

    /// "Dropping slowly over the last 3 hours".
    static func pressure(_ trend: (trend: PressureLog.Trend, hours: Int)) -> String {
        let moving = switch trend.trend {
        case .fallingFast: "Dropping fast"
        case .falling: "Dropping slowly"
        case .steady: "Steady"
        case .rising: "Rising"
        }
        return "\(moving) over the last \(trend.hours == 1 ? "hour" : "\(trend.hours) hours")"
    }

    private static func lowered(_ string: String) -> String {
        string.prefix(1).lowercased() + string.dropFirst()
    }
}
