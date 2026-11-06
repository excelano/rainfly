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

    /// The headline where nothing else says which night it is: "Rainfly off tonight".
    func headline(at now: Date) -> String {
        period(at: now) == "Tonight" ? "\(headline) tonight" : headline
    }

    /// "Tonight · sunset 8:30 PM to 8 AM" before sunset, so a daytime look reads as the
    /// night's forecast; the period alone after it.
    func periodLabel(at now: Date) -> String {
        let period = period(at: now)
        guard period == "Tonight", now < night.sunset else { return period }
        let packBy = NightWindow(night, packByMinutes: settings.packByMinutes).packBy
        let start = night.polar == nil ? "sunset \(clock(night.sunset))" : clock(night.sunset)
        return "\(period) · \(start) to \(clock(packBy))"
    }

    /// The first hour from `now` to sunset with a storm or rain the night's checks would
    /// count, which they don't cover because the night has not started.
    func beforeTonight(at now: Date) -> HourSample? {
        guard now < night.sunset else { return nil }
        return night.hours
            .sorted { $0.date < $1.date }
            .first { hour in
                hour.date.addingTimeInterval(3600) > now && hour.date < night.sunset
                    && (hour.isThunderstorm || hour.precipChance >= settings.rainChance || hour.precipAmountMM > 0)
            }
    }

    /// "Rain 30% at 3 PM, before tonight's forecast starts".
    func beforeTonightText(at now: Date) -> String? {
        beforeTonight(at: now).map { hour in
            let time = clock(hour.date)
            if hour.isThunderstorm { return "Storms possible at \(time), before tonight's forecast starts" }
            if hour.precipChance < settings.rainChance { return "Rain forecast at \(time), before tonight's forecast starts" }
            return "Rain \(percent(hour.precipChance)) at \(time), before tonight's forecast starts"
        }
    }

    /// "Rain 3 PM", for the inline complication.
    func beforeTonightBrief(at now: Date) -> String? {
        beforeTonight(at: now).map { "\($0.isThunderstorm ? "Storms" : "Rain") \(clock($0.date))" }
    }

    /// Which part of the night `now` is in, by name.
    func period(at now: Date) -> String {
        switch NightWindow(night, packByMinutes: settings.packByMinutes).phase(at: now) {
        case .evening: "Tonight"
        case .overnight: "Overnight"
        case .morning: "This morning"
        }
    }

    var reason: String {
        verdict.headline.map(describe) ?? "Clear, dry, mild."
    }

    /// The advice under the reason, in the order the main screen shows it.
    var notes: [String] {
        var notes: [String] = []
        switch night.polar {
        case .midnightSun?: notes.append("The sun stays up all night here")
        case .polarNight?: notes.append("The sun doesn't rise here tomorrow")
        case nil: break
        }
        if verdict.ventAdvice { notes.append(ventNote) }
        if verdict.bagWarning != nil { notes.append("Wear layers: it gets colder than your sleeping bag is rated for") }
        if let dryBy = verdict.dryBy {
            notes.append("Dry by ~\(clock(dryBy))")
        } else if verdict.firing(.dew) != nil || verdict.firing(.frost) != nil {
            notes.append("Won't dry by noon")
        }
        return notes
    }

    private var ventNote: String {
        let hours = NightWindow(night, packByMinutes: settings.packByMinutes).nightHours
        let damp = hours.contains { $0.humidity >= settings.ventHumidity }
        let still = hours.contains { $0.windMS < settings.calmWindMS }
        return switch (damp, still) {
        case (true, true): "Open the vents: it's a damp, still night"
        case (true, false): "Open the vents: it's a damp night"
        default: "Open the vents: there's little wind to dry the tent"
        }
    }

    func describe(_ firing: Firing) -> String {
        let time = clock(firing.at)
        return switch firing.trigger {
        case .storm: "Storms possible at \(time)"
        case .rain: precipChance(at: firing.at) < settings.rainChance ? "Rain forecast after \(time)" : "Rain \(chance(at: firing.at)) after \(time)"
        case .windRain: "Wind with rain \(chance(at: firing.at)) at \(time)"
        case .frost: "Frost likely by \(time)"
        case .dew: "Dew likely by \(time)"
        case .morningRain:
            precipChance(at: firing.at) < settings.morningRainChance
                ? "Morning rain forecast at \(time)" : "Morning rain \(chance(at: firing.at)) at \(time)"
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

    /// Tonight's result for a check in a sentence or two, naming what decided it.
    func summary(_ trigger: Trigger) -> String {
        let window = NightWindow(night, packByMinutes: settings.packByMinutes)
        let firing = verdict.firing(trigger)
        switch trigger {
        case .storm:
            return firing.map { "A thunderstorm is forecast at \(clock($0.at))." } ?? "No thunderstorms are forecast."
        case .rain:
            return rainSummary(firing, window.nightHours, threshold: settings.rainChance, period: "overnight")
                ?? "No forecast hours."
        case .morningRain:
            return rainSummary(firing, window.morningHours, threshold: settings.morningRainChance, period: "before you pack up")
                ?? "You pack up before sunrise."
        case .windRain:
            return windRainSummary(firing, window.nightHours) ?? "No forecast hours."
        case .dew, .frost:
            return spreadSummary(trigger, firing, window) ?? "No forecast hours."
        case .cold:
            guard let lowest = window.low else { return "No forecast hours." }
            if let firing {
                return "It gets colder than \(coldLimit) by \(clock(firing.at)) and drops to \(low(lowest))."
            }
            return "The lowest it gets is \(low(lowest)). It has to drop below \(coldLimit)."
        }
    }

    private func rainSummary(_ firing: Firing?, _ hours: [HourSample], threshold: Double, period: String) -> String? {
        guard let highest = hours.map(\.precipChance).max() else { return nil }
        guard let firing, let hour = hour(at: firing.at) else {
            return highest == 0
                ? "No rain is forecast \(period)."
                : "The highest chance \(period) is \(percent(highest)). It has to reach \(percent(threshold))."
        }
        if hour.precipChance < threshold {
            return "The chance is only \(percent(hour.precipChance)), but some rain is forecast to fall at \(clock(hour.date)), so it counts."
        }
        return "\(percent(hour.precipChance)) chance of rain at \(clock(hour.date)). That's at or above your \(percent(threshold))."
    }

    private func windRainSummary(_ firing: Firing?, _ hours: [HourSample]) -> String? {
        let gusting = { (hour: HourSample) in max(hour.windMS, hour.gustMS ?? 0) }
        guard let strongest = hours.map(gusting).max() else { return nil }
        if let firing, let hour = hour(at: firing.at) {
            return "Wind up to \(wind(gusting(hour))) with a \(percent(hour.precipChance)) chance of rain at \(clock(hour.date)). Both are at or over your limits."
        }
        if strongest > settings.windRainMS {
            return "Wind gets up to \(wind(strongest)), but the chance of rain stays under \(percent(settings.windRainChance)) whenever it's that windy."
        }
        return "Wind stays at \(wind(strongest)) or less. It has to go over \(windRainLimit)."
    }

    /// Dew and frost need the gap, a clear sky, calm air and the right side of freezing in
    /// the same hour, so a miss names the one that was missing.
    private func spreadSummary(_ trigger: Trigger, _ firing: Firing?, _ window: NightWindow) -> String? {
        guard let closest = window.closestSpread else { return nil }
        let wet = trigger == .dew ? "dew" : "frost"
        if let firing, let hour = hour(at: firing.at) {
            return "At \(clock(hour.date)) the air is \(spread(hour.spreadC)) from its dew point, with a clear sky and little wind, so \(wet) will form."
        }
        let within = "The air gets within \(spread(closest)) of its dew point"
        return switch SpreadMiss.of(trigger, hours: window.nightHours, settings: settings) {
        case .tooDry?, nil:
            "The air stays at least \(spread(closest)) from its dew point. It has to get within \(spreadLimit) for \(wet)."
        case .otherSideOfFreezing?:
            trigger == .dew
                ? "Dew would form, but it's below freezing, so it will be frost instead."
                : "Frost would form, but it's above freezing, so it will be dew instead."
        case .cloudy?: "\(within), but it's cloudy then. Clouds keep the tent from cooling down, so \(wet) won't form."
        case .windy?: "\(within), but it's windy then. Wind keeps the tent from cooling down, so \(wet) won't form."
        case .cloudyOrWindy?: "\(within), but whenever it does, it's either cloudy or windy, so \(wet) won't form."
        }
    }

    /// What the check looks for, in the words of the settings it uses.
    func rule(_ trigger: Trigger) -> String {
        let packBy = clock(NightWindow(night, packByMinutes: settings.packByMinutes).packBy)
        let calm = Quantity.calmWind(units).text(settings.calmWindMS)
        let condenses = "If, in the same hour, the air gets within \(spreadLimit) of its dew point, the sky is less than \(percent(settings.clearSky)) cloudy, the wind is under \(calm)"
        let anyRain = "chance of rain, or any rain at all is forecast to fall, the rainfly goes on."
        let (sunset, sunrise) = night.polar == nil ? ("sunset", "sunrise") : (clock(night.sunset), clock(night.sunrise))
        return switch trigger {
        case .storm: "If a thunderstorm is forecast any time from \(sunset) until you pack up, the rainfly goes on, even if the chance of rain is small."
        case .rain: "If any hour from \(sunset) to \(sunrise) has a \(percent(settings.rainChance)) or higher \(anyRain)"
        case .windRain: "If, in the same hour, the wind or its gusts go over \(windRainLimit) and the chance of rain is \(percent(settings.windRainChance)) or more, the rainfly goes on."
        case .frost: "\(condenses), and it's at or below freezing, the rainfly goes on."
        case .dew: "\(condenses), and it's above freezing, the rainfly goes on."
        case .morningRain: "If any hour from \(sunrise) until you pack up at \(packBy) has a \(percent(settings.morningRainChance)) or higher \(anyRain)"
        case .cold: "If the temperature drops below \(coldLimit) during the night, the rainfly goes on."
        }
    }

    static func why(_ trigger: Trigger) -> String {
        switch trigger {
        case .storm: "Thunderstorms can bring heavy rain and strong wind with almost no warning."
        case .rain: "Rain falls straight through the mesh of the inner tent."
        case .windRain: "Wind blows rain in sideways, so even a small chance of rain can soak the tent."
        case .frost: "Frost is what dew becomes below freezing. On a clear, calm night your tent cools below the air around it, and ice forms on it. When it melts, the water gets through mesh, so the rainfly catches it instead."
        case .dew: "The dew point is the temperature where air has to let go of some of its water. On a clear, calm night your tent cools below the air around it, and water collects on it, like on a cold can of soda. Water gets through mesh, so the rainfly catches it instead."
        case .morningRain: "Rain before you pack up means packing a wet tent."
        case .cold: "The rainfly traps a layer of warmer air and blocks the wind, so the tent stays a few degrees warmer."
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

    func clock(_ date: Date) -> String {
        Self.clock(date, in: night.location.timeZone, locale: locale)
    }

    /// "4 AM" on the hour, "8:40 AM" otherwise. A 24-hour clock always keeps the minutes,
    /// since an hour alone reads as a bare number: "23:00", not "23".
    static func clock(_ date: Date, in timeZone: TimeZone, locale: Locale = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let twelveHour = [.oneToTwelve, .zeroToEleven].contains(locale.hourCycle)
        var style = twelveHour && calendar.component(.minute, from: date) == 0
            ? Date.FormatStyle().hour()
            : Date.FormatStyle().hour().minute()
        style.timeZone = timeZone
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

    /// A temperature, in whole degrees.
    func temperature(_ celsius: Double) -> String {
        Quantity.cold(units).format(units.temperature(celsius))
    }

    /// A wind speed, to the step the wind settings use.
    func speed(_ metersPerSecond: Double) -> String {
        Quantity.calmWind(units).format(units.speed(metersPerSecond))
    }

    /// The night's low, written against the cold check's threshold.
    func low(_ celsius: Double) -> String {
        Quantity.cold(units).measured(celsius, against: settings.coldC)
    }

    /// The closest dew-point gap, written against the dew check's threshold.
    func spread(_ celsius: Double) -> String {
        Quantity.dewSpread(units).measured(celsius, against: settings.dewSpreadC)
    }

    func wind(_ metersPerSecond: Double) -> String {
        Quantity.windRain(units).measured(metersPerSecond, against: settings.windRainMS)
    }

    var coldLimit: String { Quantity.cold(units).text(settings.coldC) }
    var spreadLimit: String { Quantity.dewSpread(units).text(settings.dewSpreadC) }
    var windRainLimit: String { Quantity.windRain(units).text(settings.windRainMS) }

    func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }

    private func chance(at date: Date) -> String {
        percent(precipChance(at: date))
    }

    private func precipChance(at date: Date) -> Double {
        hour(at: date)?.precipChance ?? 0
    }

    func hour(at date: Date) -> HourSample? {
        night.hours.first { $0.date == date }
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
