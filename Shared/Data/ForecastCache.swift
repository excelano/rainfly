// ForecastCache.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// Fetched nights kept on the device, so a verdict holds in the backcountry. For each camp and
/// evening it keeps the latest fetch and the night's call, sealed from the last fetch before
/// the anchor; both are dropped a day after the night's sunrise.
struct ForecastCache {
    let store: Store<[NightForecast]>
    let callStore: Store<[NightCall]>

    init(directory: URL = AppGroup.applicationSupport) {
        store = Store(url: directory.appending(path: "forecasts.json"))
        callStore = Store(url: directory.appending(path: "calls.json"))
    }

    /// Seals the night's call from the latest forecast once `now` has reached the anchor, unless
    /// it is sealed already or that forecast came too late.
    func sealCall(at campName: String, on date: NightDate, now: Date, settings: Settings) {
        guard sealed(at: campName, on: date) == nil,
              let latest = night(at: campName, on: date), now >= NightWindow.anchor(of: latest),
              let call = NightCall.seal(latest, settings: settings) else { return }
        callStore.save((callStore.load() ?? []) + [call])
    }

    private func sealed(at campName: String, on date: NightDate) -> NightCall? {
        (callStore.load() ?? []).first { $0.forecast.location.name == campName && Self.date(of: $0.forecast) == date }
    }

    /// The night at `campName` that begins on the evening of `date`.
    func night(at campName: String, on date: NightDate) -> NightForecast? {
        all(at: campName, on: date).max { $0.fetchedAt < $1.fetchedAt }
    }

    /// The night's latest forecast with its call: the one sealed, or until then the one the
    /// latest forecast would seal with `settings`.
    func fetches(at campName: String, on date: NightDate, settings: Settings) -> NightFetches? {
        night(at: campName, on: date).map {
            NightFetches(latest: $0, call: sealed(at: campName, on: date) ?? NightCall.seal($0, settings: settings))
        }
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
        sealCall(at: night.location.name, on: date, now: night.fetchedAt, settings: settings)
        callStore.save((callStore.load() ?? []).filter { $0.forecast.sunrise.addingTimeInterval(86_400) > now })
        let isSame = { (old: NightForecast) in old.location.name == night.location.name && Self.date(of: old) == date }
        let all = store.load() ?? []
        let others = all.filter { $0.sunrise.addingTimeInterval(86_400) > now && !isSame($0) }
        let latest = (all.filter(isSame) + [night]).max { $0.fetchedAt < $1.fetchedAt }
        store.save(others + [latest].compactMap { $0 })
    }

    /// The evening a night belongs to: twelve hours before its sunset, since far north the
    /// sun can set after midnight.
    static func date(of night: NightForecast) -> NightDate {
        NightDate(night.sunset.addingTimeInterval(-12 * 3600), calendar: NightWindow.localCalendar(for: night.location))
    }
}
