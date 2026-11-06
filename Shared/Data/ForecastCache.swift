// ForecastCache.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// Fetched nights kept on the device, so a verdict holds in the backcountry. For each camp and
/// evening it keeps the latest fetch, the one the night is judged against and the last before
/// sunrise; a night is dropped a day after its sunrise.
struct ForecastCache {
    let store: Store<[NightForecast]>

    init(store: Store<[NightForecast]> = Store(name: "forecasts")) {
        self.store = store
    }

    /// The night at `campName` that begins on the evening of `date`.
    func night(at campName: String, on date: NightDate) -> NightForecast? {
        fetches(at: campName, on: date).max { $0.fetchedAt < $1.fetchedAt }
    }

    /// The forecast the night is judged against, fixed at 22:00.
    func decided(at campName: String, on date: NightDate) -> NightForecast? {
        NightWindow.decided(fetches(at: campName, on: date))
    }

    func beforeMorning(at campName: String, on date: NightDate) -> NightForecast? {
        NightWindow.beforeMorning(fetches(at: campName, on: date))
    }

    private func fetches(at campName: String, on date: NightDate) -> [NightForecast] {
        (store.load() ?? []).filter { $0.location.name == campName && Self.date(of: $0) == date }
    }

    /// The most recently fetched night at `campName`, whatever its date.
    func latest(at campName: String) -> NightForecast? {
        (store.load() ?? []).filter { $0.location.name == campName }.max { $0.fetchedAt < $1.fetchedAt }
    }

    func save(_ night: NightForecast, now: Date = .now) {
        let date = Self.date(of: night)
        let isSame = { (old: NightForecast) in old.location.name == night.location.name && Self.date(of: old) == date }
        let all = store.load() ?? []
        let others = all.filter { $0.sunrise.addingTimeInterval(86_400) > now && !isSame($0) }
        let same = all.filter(isSame) + [night]
        let latest = same.max { $0.fetchedAt < $1.fetchedAt }
        let kept = [latest, NightWindow.decided(same), NightWindow.beforeMorning(same)].compactMap { $0 }
        store.save(others + kept.reduce(into: []) { unique, fetch in if !unique.contains(fetch) { unique.append(fetch) } })
    }

    /// The evening a night belongs to: twelve hours before its sunset, since far north the
    /// sun can set after midnight.
    static func date(of night: NightForecast) -> NightDate {
        NightDate(night.sunset.addingTimeInterval(-12 * 3600), calendar: NightWindow.localCalendar(for: night.location))
    }
}
