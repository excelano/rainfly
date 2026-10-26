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
    /// The dry-by time, set from sunrise to pack-by when there is one.
    let dryTime: String?
    let fetchedAt: Date?
    /// The night's camp and the advice under the reason, for the phone's larger widgets.
    var camp: String?
    var notes: [String] = []

    static let noForecast = ComplicationFace(
        flyOn: nil, headline: "No forecast", detail: "Open Zeltwetter online", inline: "Zeltwetter: no forecast",
        dryTime: nil, fetchedAt: nil
    )

    /// For the watch face and widget galleries.
    static let sample = ComplicationFace(
        flyOn: true, headline: "Fly on", detail: "Dew likely by 4 AM", inline: "Fly on · Dew 4 AM",
        dryTime: nil, fetchedAt: nil, camp: "Lost Lake", notes: ["Open the vents", "Dry by ~8:40 AM"]
    )
}

extension ComplicationFace {
    init(_ text: VerdictText, morning: Bool) {
        let verdict = text.verdict
        if morning, let dryBy = verdict.dryBy {
            self.init(
                flyOn: verdict.flyOn, headline: text.headline, detail: "Dry by ~\(text.clock(dryBy))",
                inline: "Dry by \(text.compactClock(dryBy))", dryTime: text.compactClock(dryBy),
                fetchedAt: text.night.fetchedAt, camp: text.night.location.name, notes: text.notes
            )
        } else {
            self.init(
                flyOn: verdict.flyOn, headline: text.headline, detail: text.reason,
                inline: verdict.headline.map { "Fly on · \(text.brief($0))" } ?? "Fly off", dryTime: nil,
                fetchedAt: text.night.fetchedAt, camp: text.night.location.name, notes: text.notes
            )
        }
    }
}

/// The complication's entries from the cached night: one now, at sunset, at each trigger,
/// at sunrise and on every hour so the forecast's age stays current, then one at pack-by,
/// when the next night takes over.
enum ComplicationTimeline {
    static func entries(
        now: Date, settings: Settings, units: DisplayUnits, nightAt: (Date) -> NightForecast?
    ) -> [(date: Date, face: ComplicationFace)] {
        guard let night = nightAt(now) else { return [(now, .noForecast)] }
        let window = NightWindow(night, packByMinutes: settings.packByMinutes)
        let verdict = FlyEngine.evaluate(night, settings: settings)
        let text = VerdictText(night: night, verdict: verdict, settings: settings, units: units)

        var marks = [now, night.sunset, night.sunrise] + verdict.firings.map(\.at)
        var hour = Calendar.current.dateInterval(of: .hour, for: now)?.end ?? window.packBy
        while hour < window.packBy {
            marks.append(hour)
            hour.addTimeInterval(3600)
        }
        var entries = Set(marks.filter { $0 >= now && $0 < window.packBy })
            .sorted()
            .map { date in
                (date, ComplicationFace(text, morning: date >= night.sunrise))
            }

        let next = nightAt(window.packBy)
        let nextFace = next.map { next in
            let nextVerdict = FlyEngine.evaluate(next, settings: settings)
            return ComplicationFace(
                VerdictText(night: next, verdict: nextVerdict, settings: settings, units: units), morning: false
            )
        }
        entries.append((window.packBy, nextFace ?? .noForecast))
        return entries
    }
}
