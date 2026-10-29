// VerdictText.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// The words the screens show for a verdict, with times in the camp's own zone.
struct VerdictText {
    let night: NightForecast
    let verdict: Verdict
    let settings: Settings
    let units: DisplayUnits
    var locale = Locale.current

    var headline: String { verdict.flyOn ? "Rainfly on" : "Rainfly off" }

    /// Which part of the night `now` is looking at: the morning after it from sunrise until
    /// break camp, the night itself before that.
    func period(at now: Date) -> String {
        let packBy = NightWindow(night, packByMinutes: settings.packByMinutes).packBy
        return now >= night.sunrise && now < packBy ? "This morning" : "Tonight"
    }

    var reason: String {
        verdict.headline.map(describe) ?? "Clear, dry, mild."
    }

    /// The advice under the reason, in the order the main screen shows it.
    var notes: [String] {
        var notes: [String] = []
        if verdict.ventAdvice { notes.append("Open the vents") }
        if verdict.bagWarning != nil { notes.append("Below your bag rating: wear layers") }
        if let dryBy = verdict.dryBy {
            notes.append("Dry by ~\(clock(dryBy))")
        } else if verdict.firing(.dew) != nil || verdict.firing(.frost) != nil {
            notes.append("Won't dry by noon")
        }
        return notes
    }

    func describe(_ firing: Firing) -> String {
        let time = clock(firing.at)
        return switch firing.trigger {
        case .storm: "Storms possible at \(time)"
        case .rain: "Rain \(chance(at: firing.at)) after \(time)"
        case .windRain: "Wind-driven rain at \(time)"
        case .frost: "Frost likely by \(time)"
        case .dew: "Dew likely by \(time)"
        case .morningRain: "Morning rain \(chance(at: firing.at)) at \(time)"
        case .cold: "Below \(degrees(settings.coldC)) by \(time): the fly holds warmth"
        }
    }

    var checks: [Trigger] {
        let fired = verdict.firings.map(\.trigger)
        return fired + Trigger.allCases.filter { !fired.contains($0) }
    }

    static func symbol(_ trigger: Trigger) -> String {
        switch trigger {
        case .storm: "cloud.bolt.rain"
        case .rain: "cloud.rain"
        case .windRain: "cloud.heavyrain"
        case .frost: "snowflake"
        case .dew: "drop"
        case .morningRain: "cloud.sun.rain"
        case .cold: "thermometer.low"
        }
    }

    func clearName(_ trigger: Trigger) -> String {
        switch trigger {
        case .storm: "No storms"
        case .rain: "No rain"
        case .windRain: "No wind-driven rain"
        case .frost: "No frost"
        case .dew: "No dew"
        case .morningRain: "Dry morning"
        case .cold: "Stays above \(degrees(settings.coldC))"
        }
    }

    func summary(_ trigger: Trigger) -> String {
        let window = NightWindow(night, packByMinutes: settings.packByMinutes)
        let gap = degreeSpan(settings.dewSpreadC)
        let measured: String? = switch trigger {
        case .storm: nil
        case .rain: window.nightHours.map(\.precipChance).max().map { "Highest \(percent($0))" }
        case .morningRain: window.morningHours.map(\.precipChance).max().map { "Highest \(percent($0))" }
        case .windRain: window.nightHours.map { max($0.windMS, $0.gustMS ?? 0) }.max().map { "Strongest \(speed($0))" }
        case .dew, .frost: window.closestSpread.map { "Closest gap \(degreeSpan($0))" }
        case .cold: window.low.map { "Low \(degrees($0))" }
        }
        let threshold = switch trigger {
        case .storm: verdict.firing(.storm) == nil ? "None forecast" : "Thunder forecast"
        case .rain, .morningRain: "on at \(percent(trigger == .rain ? settings.rainChance : settings.morningRainChance))"
        case .windRain: "on over \(speed(settings.windRainMS)) with rain"
        case .dew, .frost: "on within \(gap), clear and calm"
        case .cold: "on below \(degrees(settings.coldC))"
        }
        return [measured, threshold].compactMap { $0 }.joined(separator: " · ")
    }

    func rule(_ trigger: Trigger) -> String {
        let gap = degreeSpan(settings.dewSpreadC)
        let sky = "cloud cover under \(percent(settings.clearSky)) and wind under \(speed(settings.calmWindMS))"
        return switch trigger {
        case .storm: "Rainfly on for a thunderstorm at any hour of the night or before you break camp."
        case .rain: "Rainfly on when any hour of the night has a \(percent(settings.rainChance)) chance of rain or more, or rain is forecast to fall."
        case .windRain: "Rainfly on when the wind or its gusts pass \(speed(settings.windRainMS)) in an hour with any chance of rain."
        case .frost: "Rainfly on when the air comes within \(gap) of its dew point, with \(sky), at or below freezing."
        case .dew: "Rainfly on when the air comes within \(gap) of its dew point, with \(sky), above freezing."
        case .morningRain: "Rainfly on when an hour between sunrise and \(clock(NightWindow(night, packByMinutes: settings.packByMinutes).packBy)) has a \(percent(settings.morningRainChance)) chance of rain or more."
        case .cold: "Rainfly on when the night drops below \(degrees(settings.coldC))."
        }
    }

    static func why(_ trigger: Trigger) -> String {
        switch trigger {
        case .storm: "Thunderstorms bring sudden downpours and gusts, often with little warning."
        case .rain: "Rain falls straight through the mesh of an inner tent and soaks what is inside."
        case .windRain: "Wind drives rain sideways under any gap, so even a small chance of rain matters when it blows."
        case .frost: "On a clear, calm night the tent cools below the air, and moisture freezes onto it. The fly takes the frost, and the inner tent stays dry."
        case .dew: "On a clear, calm night the tent cools below the air, and dew settles on it and soaks through mesh. The fly takes the dew, and the inner tent stays dry."
        case .morningRain: "Rain before you break camp means packing a wet tent. With the fly on, the inner tent packs dry."
        case .cold: "The fly holds a layer of warmer air around the inner tent and blocks the breeze, keeping the tent a few degrees warmer."
        }
    }

    /// The firing in a few words, for the inline complication: "Dew 4 AM".
    func brief(_ firing: Firing) -> String {
        let name = firing.trigger == .windRain ? "Wind rain" : Self.name(firing.trigger)
        return "\(name) \(clock(firing.at))"
    }

    static func name(_ trigger: Trigger) -> String {
        switch trigger {
        case .storm: "Storms"
        case .rain: "Rain"
        case .windRain: "Wind-driven rain"
        case .frost: "Frost"
        case .dew: "Dew"
        case .morningRain: "Morning rain"
        case .cold: "Cold"
        }
    }

    /// "4 AM" on the hour, "8:40 AM" otherwise.
    func clock(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = night.location.timeZone
        var style = calendar.component(.minute, from: date) == 0
            ? Date.FormatStyle().hour()
            : Date.FormatStyle().hour().minute()
        style.timeZone = night.location.timeZone
        style.locale = locale
        return date.formatted(style)
    }

    /// "8:40" with no AM or PM for the smallest complications, or "08:40" where the
    /// locale keeps a 24-hour clock. The format style's own omitted-AM/PM hour pads to
    /// two digits even on a 12-hour clock.
    func compactClock(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = night.location.timeZone
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let hour = parts.hour ?? 0, minute = String(format: "%02d", parts.minute ?? 0)
        switch locale.hourCycle {
        case .oneToTwelve, .zeroToEleven:
            return "\(hour % 12 == 0 ? 12 : hour % 12):\(minute)"
        default:
            return String(format: "%02d", hour) + ":" + minute
        }
    }

    func degrees(_ celsius: Double) -> String {
        "\(Int(units.temperature(celsius).rounded()))°"
    }

    func degreeSpan(_ celsius: Double) -> String {
        "\(Int(units.temperatureSpan(celsius).rounded()))°"
    }

    func speed(_ metersPerSecond: Double) -> String {
        "\(Int(units.speed(metersPerSecond).rounded())) \(units.speedUnit)"
    }

    func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }

    private func chance(at date: Date) -> String {
        percent(night.hours.first { $0.date == date }?.precipChance ?? 0)
    }

    enum Staleness { case fresh, aging, stale }

    static func age(since fetchedAt: Date, at now: Date) -> String {
        let minutes = Int(now.timeIntervalSince(fetchedAt) / 60)
        return switch minutes {
        case ..<1: "Forecast just now"
        case ..<60: "Forecast \(minutes) min old"
        default: "Forecast \(minutes / 60) h old"
        }
    }

    static func staleness(since fetchedAt: Date, at now: Date) -> Staleness {
        let hours = now.timeIntervalSince(fetchedAt) / 3600
        return hours > 24 ? .stale : hours > 12 ? .aging : .fresh
    }
}
