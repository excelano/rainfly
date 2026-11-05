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
        case .windRain: "Wind with rain \(chance(at: firing.at)) at \(time)"
        case .frost: "Frost likely by \(time)"
        case .dew: "Dew likely by \(time)"
        case .morningRain: "Morning rain \(chance(at: firing.at)) at \(time)"
        case .cold: "Below \(coldLimit) by \(time): the rainfly holds warmth"
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
        case .windRain: "No wind with rain"
        case .frost: "No frost"
        case .dew: "No dew"
        case .morningRain: "Dry morning"
        case .cold: "Stays above \(coldLimit)"
        }
    }

    func summary(_ trigger: Trigger) -> String {
        let window = NightWindow(night, packByMinutes: settings.packByMinutes)
        let chance = { (hours: [HourSample], threshold: Double) in
            hours.map(\.precipChance).max().map { "Highest \(percent($0)) · Rainfly on at \(percent(threshold)) or above" }
        }
        return switch trigger {
        case .storm: verdict.firing(.storm).map { "Forecast at \(clock($0.at))" } ?? "None forecast"
        case .rain: chance(window.nightHours, settings.rainChance) ?? "No forecast hours"
        case .morningRain: chance(window.morningHours, settings.morningRainChance) ?? "Break camp is before sunrise"
        case .windRain:
            (window.nightHours.map { max($0.windMS, $0.gustMS ?? 0) }.max().map { "Strongest \(wind($0)) · " } ?? "")
                + "Rainfly on above \(windRainLimit) with rain at \(percent(settings.windRainChance)) or above"
        case .dew, .frost:
            (window.closestSpread.map { "Closest gap \(spread($0)) · " } ?? "")
                + "Rainfly on at \(spreadLimit) or below, clear and calm"
        case .cold:
            (window.low.map { "Low \(low($0)) · " } ?? "") + "Rainfly on below \(coldLimit)"
        }
    }

    func rule(_ trigger: Trigger) -> String {
        let gap = "the gap between the air and its dew point is \(spreadLimit) or below"
        let sky = "cloud cover below \(percent(settings.clearSky)) and wind below \(Quantity.calmWind(units).text(settings.calmWindMS))"
        let packBy = clock(NightWindow(night, packByMinutes: settings.packByMinutes).packBy)
        return switch trigger {
        case .storm: "Rainfly on when any hour of the night, or before you break camp, is forecast as a thunderstorm, whatever its chance of rain."
        case .rain: "Rainfly on when any hour of the night has a chance of rain of \(percent(settings.rainChance)) or above, or rain is forecast to fall."
        case .windRain: "Rainfly on when the wind or its gusts go above \(windRainLimit) in an hour with a chance of rain of \(percent(settings.windRainChance)) or above."
        case .frost: "Rainfly on when \(gap), with \(sky), at or below freezing."
        case .dew: "Rainfly on when \(gap), with \(sky), above freezing."
        case .morningRain: "Rainfly on when an hour between sunrise and \(packBy) has a chance of rain of \(percent(settings.morningRainChance)) or above."
        case .cold: "Rainfly on when the night drops below \(coldLimit)."
        }
    }

    static func why(_ trigger: Trigger) -> String {
        switch trigger {
        case .storm: "Thunderstorms bring sudden downpours and gusts, often with little warning, so a storm in the forecast counts even when the chance of rain is low."
        case .rain: "Rain falls straight through the mesh of an inner tent and soaks what is inside."
        case .windRain: "Wind drives rain sideways under any gap, so on a windy night a smaller chance of rain than the rain check needs is enough."
        case .frost: "On a clear, calm night the tent cools below the air, and moisture freezes onto it. The rainfly takes the frost, and the inner tent stays dry."
        case .dew: "On a clear, calm night the tent cools below the air, and dew settles on it and soaks through mesh. The rainfly takes the dew, and the inner tent stays dry."
        case .morningRain: "Rain before you break camp means packing a wet tent. With the rainfly on, the inner tent packs dry."
        case .cold: "The rainfly holds a layer of warmer air around the inner tent and blocks the breeze, keeping the tent a few degrees warmer."
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
        case .windRain: "Wind with rain"
        case .frost: "Frost"
        case .dew: "Dew"
        case .morningRain: "Morning rain"
        case .cold: "Cold"
        }
    }

    /// "4 AM" on the hour, "8:40 AM" otherwise. A 24-hour clock always keeps the minutes,
    /// since an hour alone reads as a bare number: "23:00", not "23".
    func clock(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = night.location.timeZone
        let twelveHour = [.oneToTwelve, .zeroToEleven].contains(locale.hourCycle)
        var style = twelveHour && calendar.component(.minute, from: date) == 0
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

    /// The night's low, written against the cold check's threshold.
    func low(_ celsius: Double) -> String {
        Quantity.cold(units).measured(celsius, against: settings.coldC)
    }

    /// The closest dew-point gap, written against the dew check's threshold.
    func spread(_ celsius: Double) -> String {
        Quantity.dewSpread(units).measured(celsius, against: settings.dewSpreadC)
    }

    private func wind(_ metersPerSecond: Double) -> String {
        Quantity.windRain(units).measured(metersPerSecond, against: settings.windRainMS)
    }

    private var coldLimit: String { Quantity.cold(units).text(settings.coldC) }
    private var spreadLimit: String { Quantity.dewSpread(units).text(settings.dewSpreadC) }
    private var windRainLimit: String { Quantity.windRain(units).text(settings.windRainMS) }

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
        case ..<(48 * 60): "Forecast \(minutes / 60) h old"
        default: "Forecast \(minutes / (24 * 60)) days old"
        }
    }

    static func staleness(since fetchedAt: Date, at now: Date) -> Staleness {
        let hours = now.timeIntervalSince(fetchedAt) / 3600
        return hours > 24 ? .stale : hours > 12 ? .aging : .fresh
    }
}
