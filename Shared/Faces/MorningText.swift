// MorningText.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// The words for the morning after a night: whether the tent packs dry, and what Rainfly
/// expected last night.
struct MorningText {
    /// The forecast the night is judged against, fixed at 22:00.
    let decided: NightForecast
    /// The latest fetch, which becomes the record two hours after sunrise.
    let latest: NightForecast
    let settings: Settings
    let decidedSettings: Settings
    let units: DisplayUnits
    var found: DewObservation?
    var locale = Locale.current

    private var text: VerdictText {
        VerdictText(night: latest, settings: settings, units: units, locale: locale)
    }

    private var window: NightWindow { NightWindow(latest, packByMinutes: settings.packByMinutes) }

    private var decidedVerdict: Verdict { FlyEngine.evaluate(decided, settings: decidedSettings) }

    /// When tonight's forecast takes over: "12:00".
    var handoverTime: String { text.clock(window.handover) }

    /// "This morning · pack up 08:00".
    var caption: String { "This morning · pack up \(text.clock(window.packBy))" }

    enum Packing: Equatable { case dryNight, dryToPack, packingWet }

    var packing: Packing {
        guard let wet else { return .dryNight }
        guard let dryBy = wet.dryBy, dryBy <= window.packBy else { return .packingWet }
        return .dryToPack
    }

    /// When the tent should be dry, on a night that wet it.
    var dryBy: Date? { wet?.dryBy }

    var headline: String {
        switch packing {
        case .dryNight: "Dry night"
        case .dryToPack: "Dry to pack"
        case .packingWet: "Packing wet"
        }
    }

    var reason: String {
        guard let wet else { return "No dew, frost or rain on the tent last night" }
        if wet.cause == .rain, packing == .packingWet {
            return "It rained \(wet.since < latest.sunrise ? "last night" : "this morning"), so the rainfly is wet"
        }
        guard let dryBy = wet.dryBy else { return "It won't be dry before noon" }
        if dryBy <= latest.sunrise { return "The \(VerdictText.name(wet.cause).lowercased()) dried before sunrise" }
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
        hour.rains(chance: settings.morningRainChance)
    }

    private var spells: [WetFly] {
        WetFly.morning(latest, known: latest.fetchedAt, found: found, settings: decidedSettings)
    }

    private var wet: WetFly? {
        spells.last { $0.since < window.packBy }
    }

    var madeACall: Bool {
        decided.fetchedBeforeSunrise
    }

    /// "Rainfly expected dew", or a cold night when cold alone put the rainfly on.
    var lastNight: String {
        Self.expected(decidedVerdict.rain ?? decidedVerdict.condensation ?? decidedVerdict.firing(.cold))
    }

    /// What Rainfly expected of a night, for the morning question. Nil is a dry night, or no dew
    /// or frost when rain was asked about first.
    static func expected(_ firing: Firing?, afterRain: Bool = false) -> String {
        guard let trigger = firing?.trigger else { return afterRain ? "Rainfly expected no dew or frost" : "Rainfly expected a dry night" }
        return "Rainfly expected \(expectation(trigger))"
    }

    /// What a trigger means for the tent: "a storm", "rain", "dew", "a cold night".
    static func expectation(_ trigger: Trigger) -> String {
        switch trigger {
        case .storm: "a storm"
        case .rain, .windRain, .morningRain: "rain"
        case .frost: "frost"
        case .dew: "dew"
        case .cold: "a cold night"
        }
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
