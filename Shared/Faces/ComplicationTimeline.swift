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
    let fetchedAt: Date?
    /// The night's camp and the advice under the reason, for the phone's larger widgets.
    var camp: String?
    var notes: [String] = []

    static let noForecast = ComplicationFace(
        flyOn: nil, headline: "No forecast", detail: "Open Rainfly with a signal", inline: "Rainfly: no forecast", fetchedAt: nil
    )

    /// For the watch face and widget galleries.
    static let sample = ComplicationFace(
        flyOn: true, headline: "Rainfly on tonight", detail: "Dew likely by 4 AM", inline: "Rainfly on · Dew 4 AM",
        fetchedAt: nil, camp: "Lost Lake", notes: ["Open the vents: it's a damp night", "Dry around 8:40 AM tomorrow"]
    )
}

/// A night's latest forecast with its call: the one sealed, or before that the one the latest
/// forecast would seal. Nil for a night with no forecast before the anchor.
struct NightFetches: Equatable, Sendable {
    let latest: NightForecast
    var call: NightCall?

    func overnight(_ text: VerdictText, now: Date, current: CurrentConditions? = nil) -> OvernightText {
        OvernightText(text: text, call: call, now: now, current: current)
    }

    func morning(_ text: VerdictText) -> MorningText {
        MorningText(text: text, call: call)
    }
}

extension ComplicationFace {
    /// The face at `date`, for the part of the night it falls in: the verdict through the
    /// evening, what has changed since 22:00 overnight, and the night's call in the morning.
    init(_ text: VerdictText, at date: Date, fetches: NightFetches? = nil) {
        let night = text.night
        let fetches = fetches ?? NightFetches(latest: night)
        switch text.window.phase(at: date) {
        case .evening:
            self.init(evening: text, at: date)
        case .overnight:
            let overnight = fetches.overnight(text, now: date)
            self.init(
                flyOn: overnight.flyOn, headline: overnight.headline, detail: overnight.reason, inline: overnight.inline,
                fetchedAt: night.fetchedAt, camp: night.location.title, notes: overnight.notes(at: date)
            )
        case .morning:
            let morning = fetches.morning(text)
            self.init(
                flyOn: morning.call.map(\.verdict.flyOn), headline: morning.brief, detail: morning.caption, inline: morning.headline,
                fetchedAt: night.fetchedAt, camp: night.location.title
            )
        }
    }

    private init(evening text: VerdictText, at date: Date) {
        let verdict = text.verdict
        let headline = text.headline(at: date)
        if let ahead = text.beforeTonightText(at: date), let brief = text.beforeTonightBrief(at: date) {
            self.init(
                flyOn: verdict.flyOn, headline: headline, detail: ahead,
                inline: "\(brief), before tonight",
                fetchedAt: text.night.fetchedAt, camp: text.night.location.title, notes: [text.reason] + text.notes(at: date)
            )
        } else {
            self.init(
                flyOn: verdict.flyOn, headline: headline, detail: text.reason,
                inline: verdict.headline.map { "Rainfly on · \(text.brief($0))" } ?? headline,
                fetchedAt: text.night.fetchedAt, camp: text.night.location.title, notes: text.notes(at: date)
            )
        }
    }
}

/// The complication's entries from the cached night: one now, at sunset, at 22:00, at each
/// trigger, at sunrise and on every hour so the forecast's age stays current, then one at noon,
/// when the next night takes over.
enum ComplicationTimeline {
    static func entries(
        now: Date, settings: Settings, units: DisplayUnits, nightAt: (Date) -> NightFetches?
    ) -> [(date: Date, face: ComplicationFace)] {
        guard let fetches = nightAt(now) else { return [(now, .noForecast)] }
        let night = fetches.latest
        let window = NightWindow(night, packByMinutes: settings.packByMinutes)
        let text = VerdictText(night: night, settings: settings, units: units)
        let verdict = text.verdict

        var marks = [now, night.sunset, window.anchor, night.sunrise] + verdict.firings.map(\.at)
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
            ComplicationFace(VerdictText(night: next.latest, settings: settings, units: units), at: window.handover, fetches: next)
        }
        entries.append((window.handover, nextFace ?? .noForecast))
        return entries
    }
}
