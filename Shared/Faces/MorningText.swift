// MorningText.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// The words for the morning after a night: whether the tent packs dry, what Rainfly said at
/// 22:00, and how that forecast did against Apple Weather's record of the night.
struct MorningText {
    /// The forecast the night is judged against, fixed at 22:00.
    let decided: NightForecast
    /// The last forecast fetched before sunrise, to show how it moved overnight.
    let beforeMorning: NightForecast?
    /// The latest fetch, which becomes the record two hours after sunrise.
    let latest: NightForecast
    let settings: Settings
    let decidedSettings: Settings
    let units: DisplayUnits
    var alerted = false
    var locale = Locale.current

    private var text: VerdictText {
        VerdictText(night: latest, verdict: FlyEngine.evaluate(latest, settings: settings), settings: settings, units: units, locale: locale)
    }

    private var window: NightWindow { NightWindow(latest, packByMinutes: settings.packByMinutes) }

    private var decidedText: VerdictText {
        VerdictText(
            night: decided, verdict: FlyEngine.evaluate(decided, settings: decidedSettings),
            settings: decidedSettings, units: units, locale: locale
        )
    }

    private var decidedVerdict: Verdict { decidedText.verdict }

    /// When tonight's forecast takes over: "12:00".
    var handoverTime: String { text.clock(window.handover) }

    /// "This morning · pack up 08:00".
    var caption: String { "This morning · pack up \(text.clock(window.packBy))" }

    enum Packing: Equatable { case dryNight, dryToPack, packingWet }

    var packing: Packing {
        guard isWet else { return .dryNight }
        guard !rained, let dryBy = text.verdict.dryBy else { return .packingWet }
        return dryBy <= window.packBy ? .dryToPack : .packingWet
    }

    /// When the tent should be dry, on a night that wet it.
    var dryBy: Date? {
        isWet && !rained ? text.verdict.dryBy : nil
    }

    var headline: String {
        switch packing {
        case .dryNight: "Dry night"
        case .dryToPack: "Dry to pack"
        case .packingWet: "Packing wet"
        }
    }

    var reason: String {
        if let rainedAt { return "It rained \(rainedAt < latest.sunrise ? "last night" : "this morning"), so the rainfly is wet" }
        guard isWet else { return "No dew, frost or rain on the tent last night" }
        guard let dryBy = text.verdict.dryBy else { return "It won't be dry before noon" }
        let at = "It should be dry around \(text.clock(dryBy))"
        if dryBy <= window.packBy { return "\(at), before you pack up at \(text.clock(window.packBy))" }
        return "\(at), \(Self.duration(dryBy.timeIntervalSince(window.packBy))) after you pack up"
    }

    /// The advice under the reason, when the tent packs wet.
    var advice: String? {
        packing == .packingWet ? "Shake the rainfly off and pack it separately so the tent stays dry" : nil
    }

    /// Rain on its way before noon, which changes how to pack: "Rain 60% at 10:00, before you
    /// pack up".
    func rainAhead(at now: Date) -> String? {
        let ahead = latest.hours
            .sorted { $0.date < $1.date }
            .first { $0.date.addingTimeInterval(3600) > now && $0.date < window.handover && (rains($0)) }
        return ahead.map { hour in
            let chance = hour.precipChance >= settings.morningRainChance ? "Rain \(text.percent(hour.precipChance))" : "Rain"
            let when = hour.date < window.packBy ? ", before you pack up" : " this morning"
            return "\(chance) at \(text.clock(hour.date))\(when)"
        }
    }

    private func rains(_ hour: HourSample) -> Bool {
        hour.precipChance >= settings.morningRainChance || hour.precipAmountMM > 0
    }

    private var isWet: Bool {
        rained || text.verdict.firing(.dew) != nil || text.verdict.firing(.frost) != nil
    }

    private var rained: Bool { rainedAt != nil }

    private var rainedAt: Date? {
        let seen = window.morningHours.filter { $0.date < latest.fetchedAt }
        return (window.nightHours + seen).first { $0.precipAmountMM > 0 }?.date
    }

    /// When the night was judged from: 22:00, or the first fetch when it came later.
    var decidedAt: String {
        text.clock(NightWindow.decidedAt(decided))
    }

    var madeACall: Bool {
        decided.fetchedAt < decided.sunrise
    }

    /// "At 22:00, Rainfly said on".
    var lastNightTitle: String {
        "At \(decidedAt), Rainfly said \(decidedVerdict.flyOn ? "on" : "off")"
    }

    /// Why it said so, or how the forecast changed before sunrise.
    var lastNightDetail: String {
        if let beforeMorning {
            let overnight = FlyEngine.evaluate(beforeMorning, settings: decidedSettings)
            if overnight.flyOn != decidedVerdict.flyOn {
                let by = "By \(text.clock(beforeMorning.fetchedAt)) the forecast changed to"
                guard overnight.flyOn else { return "\(by) off." }
                let because = overnight.headline.map { " because of \(Self.cause($0.trigger))" } ?? ""
                return "\(by) on\(because)\(alerted ? ", and Rainfly sent you an alert" : "")."
            }
        }
        guard !decidedVerdict.firings.isEmpty else { return "It expected a clear, dry night." }
        let causes = decidedVerdict.firings.map { "\(Self.cause($0.trigger)) \(Self.from($0.trigger)) \(text.clock($0.at))" }
        return "Because of \(Self.list(causes))."
    }

    /// "Was the 22:00 forecast right?"
    var reviewTitle: String { "Was the \(decidedAt) forecast right?" }

    /// Nil until WeatherKit's record of the night is in.
    var review: NightReview? {
        NightReview.isRecord(latest) ? NightReview(decided: decided, record: latest, settings: decidedSettings) : nil
    }

    /// Shown in place of the checks while the record is not in yet.
    var reviewPending: String {
        "Apple Weather's record of last night will be ready around \(text.clock(NightReview.recordReady(latest)))."
    }

    /// What the record shows for one check, and what Rainfly expected when it differs.
    func explain(_ check: NightReview.Check) -> String {
        let record = "Apple Weather's record shows"
        switch check.trigger {
        case .dew, .frost:
            let wet = check.trigger == .dew ? "dew" : "frost"
            let happened: String
            if let firing = check.happened, let hour = latest.hours.first(where: { $0.date == firing.at }) {
                happened = "\(record) the air got within \(decidedText.spread(hour.spreadC)) of its dew point at \(text.clock(firing.at)), with a clear sky and little wind"
            } else {
                happened = "\(record) \(missed(check.trigger, in: latest))"
            }
            guard !check.isRight else { return "\(happened)." }
            if let expected = check.expected {
                return "Rainfly expected \(wet) from \(text.clock(expected.at)). \(happened)."
            }
            return "At \(decidedAt) Rainfly expected \(expectedMiss(check.trigger)), so no \(wet). \(happened)."
        case .rain, .morningRain:
            let hours = check.trigger == .rain ? \NightWindow.nightHours : \NightWindow.morningHours
            let chance = { (night: NightForecast) in
                NightWindow(night, packByMinutes: decidedSettings.packByMinutes)[keyPath: hours].map(\.precipChance).max() ?? 0
            }
            var said = "At \(decidedAt) the chance was \(text.percent(chance(decided)))."
            if let beforeMorning, chance(beforeMorning) >= chance(decided) + 0.1 {
                said += " It went up to \(text.percent(chance(beforeMorning))) overnight"
                return said + (check.happened.map { ", and rain fell from \(text.clock($0.at))." } ?? ", but no rain fell.")
            }
            return said + (check.happened.map { " Rain fell from \(text.clock($0.at))." } ?? " No rain fell.")
        case .storm:
            let said = check.expected.map { "A thunderstorm was forecast at \(text.clock($0.at))." } ?? "No thunderstorms were forecast."
            return said + (check.happened.map { " \(record) one at \(text.clock($0.at))." } ?? " \(record) none.")
        case .windRain:
            let said = check.expected.map { "Rainfly expected wind with rain at \(text.clock($0.at))." } ?? "Rainfly didn't expect wind with rain."
            return said + (check.happened.map { " \(record) wind with rain at \(text.clock($0.at))." } ?? " \(record) the wind and the rain never came together.")
        case .cold:
            let expectedLow = NightWindow(decided, packByMinutes: decidedSettings.packByMinutes).low
            let actualLow = NightWindow(latest, packByMinutes: decidedSettings.packByMinutes).low
            guard let expectedLow, let actualLow else { return "No hours to compare." }
            let below = check.happened == nil ? ", so it never got below the \(decidedText.coldLimit) limit" : ", below the \(decidedText.coldLimit) limit"
            return "Rainfly expected a low of \(text.low(expectedLow)). It got down to \(text.low(actualLow))\(below)."
        }
    }

    private func missed(_ trigger: Trigger, in night: NightForecast) -> String {
        let hours = NightWindow(night, packByMinutes: decidedSettings.packByMinutes).nightHours
        return switch SpreadMiss.of(trigger, hours: hours, settings: decidedSettings) {
        case .tooDry(let closest)?: "the air stayed at least \(decidedText.spread(closest)) from its dew point"
        case .cloudy?: "it was cloudy whenever the air got close to its dew point"
        case .windy?: "it was windy whenever the air got close to its dew point"
        case .cloudyOrWindy?: "it was cloudy or windy whenever the air got close to its dew point"
        case .otherSideOfFrostLine?:
            trigger == .dew
                ? "the air got down to \(decidedText.frostLine), so it was frost instead"
                : "the air stayed warmer than \(decidedText.frostLine), so it was dew instead"
        case nil: "no hours for the night"
        }
    }

    private func expectedMiss(_ trigger: Trigger) -> String {
        let hours = NightWindow(decided, packByMinutes: decidedSettings.packByMinutes).nightHours
        return switch SpreadMiss.of(trigger, hours: hours, settings: decidedSettings) {
        case .tooDry?, nil: "the air to stay too dry"
        case .cloudy?: "clouds all night"
        case .windy?: "wind all night"
        case .cloudyOrWindy?: "clouds or wind all night"
        case .otherSideOfFrostLine?: trigger == .dew ? "the air to get down to \(decidedText.frostLine)" : "the air to stay warmer than \(decidedText.frostLine)"
        }
    }

    private static func cause(_ trigger: Trigger) -> String {
        switch trigger {
        case .storm: "storms"
        case .rain: "rain"
        case .windRain: "wind with rain"
        case .frost: "frost"
        case .dew: "dew"
        case .morningRain: "morning rain"
        case .cold: "cold"
        }
    }

    private static func from(_ trigger: Trigger) -> String {
        trigger == .storm || trigger == .windRain || trigger == .morningRain ? "at" : "from"
    }

    private static func list(_ items: [String]) -> String {
        guard let last = items.last else { return "" }
        return items.count == 1 ? last : items.dropLast().joined(separator: ", ") + " and " + last
    }

    /// "an hour and a half", rounded to the half hour.
    static func duration(_ interval: TimeInterval) -> String {
        let halves = max(1, Int((interval / 1800).rounded()))
        let hours = halves / 2, half = halves % 2 == 1
        let words = ["", "an hour", "two hours", "three hours", "four hours"]
        switch (hours, half) {
        case (0, _): return "half an hour"
        case (1, true): return "an hour and a half"
        case (2...4, true): return "\(["", "", "two", "three", "four"][hours]) and a half hours"
        case (1...4, false): return words[hours]
        default: return "\(hours) hours"
        }
    }
}
