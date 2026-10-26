// ForecastCache.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// Fetched nights kept on the watch, so a verdict holds in the backcountry. One night per
/// camp and evening; a night is dropped a day after its sunrise.
struct ForecastCache {
    let store: Store<[NightForecast]>

    init(store: Store<[NightForecast]> = Store(name: "forecasts")) {
        self.store = store
    }

    /// The night at `campName` that begins on the evening of `date`.
    func night(at campName: String, on date: NightDate) -> NightForecast? {
        (store.load() ?? []).first { $0.location.name == campName && Self.date(of: $0) == date }
    }

    /// The most recently fetched night at `campName`, whatever its date.
    func latest(at campName: String) -> NightForecast? {
        (store.load() ?? []).filter { $0.location.name == campName }.max { $0.fetchedAt < $1.fetchedAt }
    }

    func save(_ night: NightForecast, now: Date = .now) {
        let date = Self.date(of: night)
        let kept = (store.load() ?? []).filter { old in
            old.sunrise.addingTimeInterval(86_400) > now
                && !(old.location.name == night.location.name && Self.date(of: old) == date)
        }
        store.save(kept + [night])
    }

    static func date(of night: NightForecast) -> NightDate {
        NightDate(night.sunset, calendar: NightWindow.localCalendar(for: night.location))
    }
}
