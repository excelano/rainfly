// FlyEngine.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// Decides whether the rain fly goes on. Each trigger is tested on its own, and any one
/// firing puts the fly on. Storms are tested across the night and the morning, rain and
/// morning rain each in their own part, and every other trigger across the night only.
enum FlyEngine {
    static func evaluate(_ night: NightForecast, settings: Settings, dryByModel: DryByModel = DryByModel()) -> Verdict {
        let window = NightWindow(night, packByMinutes: settings.packByMinutes)
        let nightHours = window.nightHours
        let morningHours = window.morningHours

        var earliest: [Trigger: Date] = [:]
        func record(_ trigger: Trigger, in hours: [HourSample], when fires: (HourSample) -> Bool) {
            earliest[trigger] = hours.first(where: fires)?.date
        }

        let s = settings
        func rains(_ hour: HourSample, chance: Double) -> Bool {
            hour.precipChance >= chance || hour.precipAmountMM > 0
        }
        func condenses(_ hour: HourSample) -> Bool {
            hour.spreadC <= s.dewSpreadC && hour.cloudCover < s.clearSky && hour.windMS < s.calmWindMS
        }

        record(.storm, in: nightHours + morningHours) { $0.isThunderstorm }
        record(.rain, in: nightHours) { rains($0, chance: s.rainChance) }
        record(.morningRain, in: morningHours) { rains($0, chance: s.morningRainChance) }
        record(.windRain, in: nightHours) { max($0.windMS, $0.gustMS ?? 0) > s.windRainMS && $0.precipChance > 0 }
        record(.dew, in: nightHours) { condenses($0) && $0.tempC > 0 }
        record(.frost, in: nightHours) { condenses($0) && $0.tempC <= 0 }
        record(.cold, in: nightHours) { $0.tempC < s.coldC }

        let firings = earliest
            .map { Firing(trigger: $0.key, at: $0.value) }
            .sorted { ($0.trigger.priority, $0.at) < ($1.trigger.priority, $1.at) }
        let flyOn = !firings.isEmpty

        let ventAdvice = flyOn && nightHours.contains { $0.humidity >= s.ventHumidity || $0.windMS < s.calmWindMS }

        var bagWarning: BagWarning?
        if let rating = s.bagRatingC, let low = window.low, low < rating {
            bagWarning = BagWarning(lowC: low, ratingC: rating)
        }

        let frost = earliest[.frost] != nil
        let wet = frost || earliest[.dew] != nil
        let dryBy = wet ? dryByModel.dryBy(night, frost: frost, calendar: window.calendar) : nil

        return Verdict(flyOn: flyOn, firings: firings, ventAdvice: ventAdvice, bagWarning: bagWarning, dryBy: dryBy)
    }
}
