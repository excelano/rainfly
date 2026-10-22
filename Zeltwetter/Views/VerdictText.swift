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

    var headline: String { verdict.flyOn ? "Fly on" : "Fly off" }

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
        case .cold: "Below \(degrees(settings.coldC)) by \(time)"
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
