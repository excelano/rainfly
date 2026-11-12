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
    let decidedSettings: Settings
    let now: Date
    let ahead: VerdictText
    private let added: Firing?
    private let dropped: Firing?
    private let wet: WetFly?

    init(text: VerdictText, decided: NightForecast, decidedSettings: Settings, now: Date, current: CurrentConditions? = nil) {
        self.text = text
        self.decided = decided
        self.decidedSettings = decidedSettings
        self.now = now
        let ahead = text.ahead(of: now)
        let decidedAhead = FlyEngine.evaluate(decided, settings: decidedSettings, from: now)
        self.ahead = ahead
        added = ahead.verdict.firings.first { decidedAhead.firing($0.trigger) == nil }
        dropped = decidedAhead.firings.first { ahead.verdict.firing($0.trigger) == nil }
        wet = WetFly.at(now, night: text.night, current: current, settings: text.settings)
    }

    var flyOn: Bool { ahead.verdict.flyOn || wet != nil }

    var headline: String { flyOn ? "Rainfly on" : "Rainfly off" }

    private var decidedText: VerdictText {
        VerdictText(
            night: decided, verdict: FlyEngine.evaluate(decided, settings: decidedSettings),
            settings: decidedSettings, units: text.units, locale: text.locale
        )
    }

    private var decidedVerdict: Verdict { decidedText.verdict }

    private var decidedAt: String {
        text.clock(NightWindow.decidedAt(decided))
    }

    /// "Overnight · updated 02:10".
    var caption: String { "Overnight · updated \(text.clock(text.night.fetchedAt))" }

    var hasChanged: Bool { added != nil || dropped != nil }

    var change: String? {
        if let added { return "New since \(decidedAt): \(Self.lowered(ahead.describe(added)))" }
        if let dropped, wet == nil {
            return "No longer expected since \(decidedAt): \(VerdictText.name(dropped.trigger).lowercased())"
        }
        return nil
    }

    var reason: String {
        if let change { return change }
        let next = ahead.verdict.headline
        if let next, next.trigger.isRain { return ahead.describe(next) }
        if let wet { return describe(wet) }
        return next.map(ahead.describe) ?? "Nothing more expected tonight"
    }

    private func describe(_ wet: WetFly) -> String {
        let since = text.clock(wet.since)
        return switch wet.cause {
        case .frost: "Frost on the rainfly since \(since)"
        case .dew: "Dew on the rainfly since \(since)"
        default: "The rainfly is wet from rain at \(since)"
        }
    }

    /// What Rainfly said at 22:00 when the forecast has moved, or that it hasn't; nil while the
    /// latest forecast is the only one, with nothing earlier to compare.
    var note: String? {
        guard decided.fetchedAt != text.night.fetchedAt else { return nil }
        guard hasChanged else { return "Same as the \(decidedAt) forecast" }
        let said = "At \(decidedAt), Rainfly said \(decidedVerdict.flyOn ? "on" : "off")"
        return decidedVerdict.headline.map { "\(said): \(Self.lowered(decidedText.describe($0)))" } ?? said
    }

    func notes(at now: Date) -> [String] {
        ahead.conditionNotes + [text.dryNote(at: now)].compactMap { $0 }
    }

    var inline: String {
        if let added { return "New: \(Self.lowered(ahead.brief(added)))" }
        if let next = ahead.verdict.headline { return "Rainfly on · \(ahead.brief(next))" }
        return wet == nil ? headline : "Rainfly on · wet"
    }

    /// The forecast hours from `now` to sunrise, at most eight.
    var hoursAhead: [HourSample] {
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
