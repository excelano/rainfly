// ForecastCache.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// Fetched nights kept on the device, so a verdict holds in the backcountry. For each camp and
/// evening it keeps the latest fetch, the one the night is judged against and the last before
/// sunrise; a night is dropped a day after its sunrise. Beside them it keeps the dew diary's
/// answers, which the phone records and sends to the watch, so every screen's morning goes by
/// what was found.
struct ForecastCache {
    let store: Store<[NightForecast]>
    let foundStore: Store<[FoundNight]>

    init(store: Store<[NightForecast]> = Store(name: "forecasts"), foundStore: Store<[FoundNight]> = Store(name: "found")) {
        self.store = store
        self.foundStore = foundStore
    }

    /// The night at `campName` that begins on the evening of `date`.
    func night(at campName: String, on date: NightDate) -> NightForecast? {
        all(at: campName, on: date).max { $0.fetchedAt < $1.fetchedAt }
    }

    /// The forecast the night is judged against, fixed at 22:00.
    func decided(at campName: String, on date: NightDate) -> NightForecast? {
        NightWindow.decided(all(at: campName, on: date))
    }

    /// The night's latest forecast with the one its overnight and morning words compare against.
    func fetches(at campName: String, on date: NightDate) -> NightFetches? {
        let all = all(at: campName, on: date)
        return all.max { $0.fetchedAt < $1.fetchedAt }.map {
            NightFetches(
                latest: $0, decided: NightWindow.decided(all),
                found: found(at: campName, on: date)
            )
        }
    }

    /// What the dew diary found the morning after the night at `campName` on `date`.
    func found(at campName: String, on date: NightDate) -> DewObservation? {
        allFound.first { $0.campName == campName && $0.date == date }?.observation
    }

    var allFound: [FoundNight] {
        foundStore.load() ?? []
    }

    /// Keeps the answers given, replacing one for the same night, and drops those more than
    /// two days old.
    func save(found: [FoundNight], now: Date = .now) {
        let replaced = { (old: FoundNight) in found.contains { $0.campName == old.campName && $0.date == old.date } }
        foundStore.save((allFound.filter { !replaced($0) } + found).filter { Self.isRecent($0, now: now) })
    }

    /// Whether an answer still belongs to a morning that can be on screen.
    static func isRecent(_ found: FoundNight, now: Date = .now) -> Bool {
        now.timeIntervalSince(found.observation.at) < 2 * 86_400
    }

    private func all(at campName: String, on date: NightDate) -> [NightForecast] {
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
        let kept = [latest, NightWindow.decided(same)].compactMap { $0 }
        store.save(others + kept.reduce(into: []) { unique, fetch in if !unique.contains(fetch) { unique.append(fetch) } })
    }

    /// The evening a night belongs to: twelve hours before its sunset, since far north the
    /// sun can set after midnight.
    static func date(of night: NightForecast) -> NightDate {
        NightDate(night.sunset.addingTimeInterval(-12 * 3600), calendar: NightWindow.localCalendar(for: night.location))
    }
}
