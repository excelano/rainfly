// ForecastCache.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// Fetched nights kept on the device, so a verdict holds in the backcountry. For each camp and
/// evening it keeps the latest fetch and the night's call, sealed from the last fetch before
/// the anchor; both are dropped a day after the night's sunrise. Beside them it keeps the dew
/// diary's answers, which the phone records and sends to the watch.
struct ForecastCache {
    let store: Store<[NightForecast]>
    let callStore: Store<[NightCall]>
    let foundStore: Store<[FoundNight]>

    init(directory: URL = AppGroup.applicationSupport) {
        store = Store(url: directory.appending(path: "forecasts.json"))
        callStore = Store(url: directory.appending(path: "calls.json"))
        foundStore = Store(url: directory.appending(path: "found.json"))
    }

    /// The night's call: the one sealed, or sealed now from the latest forecast once `now` has
    /// reached the anchor. Nil before the anchor, and for a night with no fetch before it.
    func call(at campName: String, on date: NightDate, now: Date, settings: Settings) -> NightCall? {
        if let sealed = sealed(at: campName, on: date) { return sealed }
        guard let latest = night(at: campName, on: date), now >= NightWindow.anchor(of: latest),
              let call = NightCall.seal(latest, settings: settings) else { return nil }
        callStore.save((callStore.load() ?? []) + [call])
        return call
    }

    private func sealed(at campName: String, on date: NightDate) -> NightCall? {
        (callStore.load() ?? []).first { $0.forecast.location.name == campName && Self.date(of: $0.forecast) == date }
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

    /// A fetch made at or after the anchor seals the night's call from the fetch it replaces.
    func save(_ night: NightForecast, now: Date = .now, settings: Settings) {
        let date = Self.date(of: night)
        _ = call(at: night.location.name, on: date, now: night.fetchedAt, settings: settings)
        callStore.save((callStore.load() ?? []).filter { $0.forecast.sunrise.addingTimeInterval(86_400) > now })
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
