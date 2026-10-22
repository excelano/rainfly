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

    /// The night at `campName` that begins on the evening of `evening`.
    func night(at campName: String, evening: Date) -> NightForecast? {
        (store.load() ?? []).first { $0.location.name == campName && Self.begins($0, on: evening) }
    }

    /// The night that matters at `now` for a camp in the watch's own zone: last night
    /// until pack-by, tonight from then on.
    func night(at campName: String, covering now: Date, packByMinutes: Int) -> NightForecast? {
        night(at: campName, evening: NightWindow.evening(at: now, packByMinutes: packByMinutes, calendar: .current))
    }

    func save(_ night: NightForecast, now: Date = .now) {
        let calendar = NightWindow.localCalendar(for: night.location)
        let evening = calendar.startOfDay(for: night.sunset)
        let kept = (store.load() ?? []).filter { old in
            old.sunrise.addingTimeInterval(86_400) > now
                && !(old.location.name == night.location.name && Self.begins(old, on: evening))
        }
        store.save(kept + [night])
    }

    private static func begins(_ night: NightForecast, on evening: Date) -> Bool {
        NightWindow.localCalendar(for: night.location).isDate(night.sunset, inSameDayAs: evening)
    }
}
