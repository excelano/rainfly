// FlyEngine.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// Decides whether the rain fly goes on. Each trigger is tested on its own, and any one
/// firing puts the fly on. Storms are tested across the night and the morning, rain and
/// morning rain each in their own part, and every other trigger across the night only.
enum FlyEngine {
    /// The air temperature at or under which condensation is frost. A clear, calm night cools
    /// the tent a few degrees below the air, so the tent freezes before the air does.
    static let frostAirC = 2.0

    static func isFrostAir(_ tempC: Double) -> Bool { tempC <= frostAirC }

    static func condenses(spreadC: Double, cloudCover: Double, windMS: Double, settings: Settings) -> Bool {
        spreadC <= settings.dewSpreadC && cloudCover < settings.clearSky && windMS < settings.calmWindMS
    }

    static func evaluate(
        _ night: NightForecast, settings: Settings, from start: Date = .distantPast, dryByModel: DryByModel = DryByModel()
    ) -> Verdict {
        let window = NightWindow(night, packByMinutes: settings.packByMinutes, from: start)
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
            Self.condenses(spreadC: hour.spreadC, cloudCover: hour.cloudCover, windMS: hour.windMS, settings: s)
        }

        record(.storm, in: nightHours + morningHours) { $0.isThunderstorm }
        record(.rain, in: nightHours) { rains($0, chance: s.rainChance) }
        record(.morningRain, in: morningHours) { rains($0, chance: s.morningRainChance) }
        record(.windRain, in: nightHours) { max($0.windMS, $0.gustMS ?? 0) > s.windRainMS && $0.precipChance >= s.windRainChance }
        record(.dew, in: nightHours) { condenses($0) && !isFrostAir($0.tempC) }
        record(.frost, in: nightHours) { condenses($0) && isFrostAir($0.tempC) }
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

        let wet = WetFly.packing(night, packBy: window.packBy, settings: settings, dryByModel: dryByModel)

        return Verdict(flyOn: flyOn, firings: firings, ventAdvice: ventAdvice, bagWarning: bagWarning, wet: wet)
    }
}
