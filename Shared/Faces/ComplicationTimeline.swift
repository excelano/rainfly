// ComplicationTimeline.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// What a complication shows at one moment, already in words.
struct ComplicationFace: Equatable, Sendable {
    /// Nil when there is no forecast for the night.
    let flyOn: Bool?
    let headline: String
    let detail: String
    let inline: String
    /// The dry-by time, set from sunrise to noon when there is one.
    let dryTime: String?
    let fetchedAt: Date?
    /// The night's camp and the advice under the reason, for the phone's larger widgets.
    var camp: String?
    var notes: [String] = []

    static let noForecast = ComplicationFace(
        flyOn: nil, headline: "No forecast", detail: "Open Rainfly with a signal", inline: "Rainfly: no forecast",
        dryTime: nil, fetchedAt: nil
    )

    /// For the watch face and widget galleries.
    static let sample = ComplicationFace(
        flyOn: true, headline: "Rainfly on tonight", detail: "Dew likely by 4 AM", inline: "Rainfly on · Dew 4 AM",
        dryTime: nil, fetchedAt: nil, camp: "Lost Lake", notes: ["Open the vents: it's a damp night", "Dry by ~8:40 AM"]
    )
}

/// A night's latest forecast with the ones its overnight and morning words compare against.
struct NightFetches: Equatable, Sendable {
    let latest: NightForecast
    var decided: NightForecast?
    var beforeMorning: NightForecast?
}

extension ComplicationFace {
    /// The face at `date`, for the part of the night it falls in: the verdict through the
    /// evening, what has changed since 22:00 overnight, and packing up in the morning.
    init(_ text: VerdictText, at date: Date, fetches: NightFetches? = nil) {
        let night = text.night
        switch NightWindow(night, packByMinutes: text.settings.packByMinutes).phase(at: date) {
        case .evening:
            self.init(evening: text, at: date)
        case .overnight:
            let overnight = OvernightText(text: text, decided: fetches?.decided ?? night)
            self.init(
                flyOn: text.verdict.flyOn, headline: text.headline, detail: overnight.reason,
                inline: overnight.brief ?? text.verdict.headline.map { "Rainfly on · \(text.brief($0))" } ?? text.headline,
                dryTime: nil, fetchedAt: night.fetchedAt, camp: night.location.title, notes: text.notes
            )
        case .morning:
            let morning = MorningText(
                decided: fetches?.decided ?? night, beforeMorning: fetches?.beforeMorning, latest: night,
                settings: text.settings, units: text.units, locale: text.locale
            )
            let dryTime = morning.dryBy.map(text.compactClock)
            self.init(
                flyOn: morning.packing != .dryNight, headline: morning.headline, detail: morning.reason,
                inline: dryTime.map { "\(morning.headline) · dry \($0)" } ?? morning.headline, dryTime: dryTime,
                fetchedAt: night.fetchedAt, camp: night.location.title,
                notes: [morning.rainAhead(at: date), morning.advice].compactMap { $0 }
            )
        }
    }

    private init(evening text: VerdictText, at date: Date) {
        let verdict = text.verdict
        let headline = text.headline(at: date)
        if let ahead = text.beforeTonightText(at: date), let brief = text.beforeTonightBrief(at: date) {
            self.init(
                flyOn: verdict.flyOn, headline: headline, detail: ahead,
                inline: "\(brief), before tonight", dryTime: nil,
                fetchedAt: text.night.fetchedAt, camp: text.night.location.title, notes: [text.reason] + text.notes
            )
        } else {
            self.init(
                flyOn: verdict.flyOn, headline: headline, detail: text.reason,
                inline: verdict.headline.map { "Rainfly on · \(text.brief($0))" } ?? headline, dryTime: nil,
                fetchedAt: text.night.fetchedAt, camp: text.night.location.title, notes: text.notes
            )
        }
    }
}

/// The complication's entries from the cached night: one now, at sunset, at 22:00, at each
/// trigger, at sunrise, when the record arrives and on every hour so the forecast's age stays
/// current, then one at noon, when the next night takes over.
enum ComplicationTimeline {
    static func entries(
        now: Date, settings: Settings, units: DisplayUnits, nightAt: (Date) -> NightFetches?
    ) -> [(date: Date, face: ComplicationFace)] {
        guard let fetches = nightAt(now) else { return [(now, .noForecast)] }
        let night = fetches.latest
        let window = NightWindow(night, packByMinutes: settings.packByMinutes)
        let verdict = FlyEngine.evaluate(night, settings: settings)
        let text = VerdictText(night: night, verdict: verdict, settings: settings, units: units)

        var marks = [now, night.sunset, window.anchor, night.sunrise, NightReview.recordReady(night)] + verdict.firings.map(\.at)
        var hour = Calendar.current.dateInterval(of: .hour, for: now)?.end ?? window.handover
        while hour < window.handover {
            marks.append(hour)
            hour.addTimeInterval(3600)
        }
        var entries = Set(marks.filter { $0 >= now && $0 < window.handover })
            .sorted()
            .map { date in
                (date, ComplicationFace(text, at: date, fetches: fetches))
            }

        let nextFace = nightAt(window.handover).map { next in
            let nextVerdict = FlyEngine.evaluate(next.latest, settings: settings)
            return ComplicationFace(
                VerdictText(night: next.latest, verdict: nextVerdict, settings: settings, units: units),
                at: window.handover, fetches: next
            )
        }
        entries.append((window.handover, nextFace ?? .noForecast))
        return entries
    }
}
