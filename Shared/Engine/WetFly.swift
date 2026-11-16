// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

struct WetFly: Codable, Equatable, Sendable {
    let cause: Trigger
    let since: Date
    let dryBy: Date?

    func isWet(at moment: Date) -> Bool {
        since <= moment && dryBy.map { $0 > moment } ?? true
    }

    static func at(
        _ moment: Date, night: NightForecast, current: CurrentConditions?, settings: Settings,
        dryByModel: DryByModel = DryByModel()
    ) -> WetFly? {
        spells(night, wettingBefore: moment, current: current, settings: settings, dryByModel: dryByModel)
            .last { $0.isWet(at: moment) }
    }

    static func packing(
        _ night: NightForecast, packBy: Date, known: Date = .distantPast, settings: Settings,
        dryByModel: DryByModel = DryByModel()
    ) -> WetFly? {
        morning(night, known: known, settings: settings, dryByModel: dryByModel).last { $0.since < packBy }
    }

    static func morning(
        _ night: NightForecast, known: Date = .distantPast, found: DewObservation? = nil, settings: Settings,
        dryByModel: DryByModel = DryByModel()
    ) -> [WetFly] {
        spells(night, wettingBefore: max(night.sunrise, known), found: found, settings: settings, dryByModel: dryByModel)
    }

    /// `found` is what the diary recorded on the fly, which overrides the forecast's hours: wet
    /// from that moment if the hours had it dry, and on a dry answer no dew or frost before it
    /// and nothing still wet at it.
    static func spells(
        _ night: NightForecast, wettingBefore: Date, current: CurrentConditions? = nil, found: DewObservation? = nil,
        settings: Settings, dryByModel: DryByModel = DryByModel()
    ) -> [WetFly] {
        let noon = NightWindow(night, packByMinutes: settings.packByMinutes).handover
        let sunlit = night.polar != .polarNight
        var spells: [WetFly] = []
        var wet: (cause: Trigger, since: Date)?
        var left = 0.0
        let seen = Seen(found)
        let foundDryAt = seen.flatMap { $0.cause == nil ? $0.at : nil }

        func wetted(by cause: Trigger, at date: Date) {
            if wet.map({ cause.priority < $0.cause.priority }) ?? true { wet = (cause, date) }
            left = dryByModel.toDry(wet!.cause)
        }

        func dry(_ hour: HourSample, from start: Date, to end: Date, inSun: Bool) {
            guard let current = wet, end > start else { return }
            let rate = dryByModel.dryingRate(hour, sunlit: inSun)
            let hours = end.timeIntervalSince(start) / 3600
            guard rate * hours >= left else {
                left -= rate * hours
                return
            }
            let dry = start.addingTimeInterval(left / rate * 3600)
            let rounded = Date(timeIntervalSinceReferenceDate: (dry.timeIntervalSinceReferenceDate / 900).rounded(.up) * 900)
            spells.append(WetFly(cause: current.cause, since: current.since, dryBy: rounded))
            wet = nil
        }

        let hours = night.hours
            .sorted { $0.date < $1.date }
            .filter { $0.date.addingTimeInterval(3600) > night.sunset && $0.date < noon }
        for hour in hours {
            let end = min(hour.date.addingTimeInterval(3600), noon)
            if hour.date < wettingBefore,
               let cause = cause(rained: hour.precipAmountMM > 0, condenses: hour.date < night.sunrise, spreadC: hour.spreadC,
                                 cloudCover: hour.cloudCover, windMS: hour.windMS, tempC: hour.tempC, settings: settings),
               cause == .rain || foundDryAt.map({ hour.date >= $0 }) ?? true {
                wetted(by: cause, at: hour.date)
            } else {
                let sunrise = min(max(night.sunrise, hour.date), end)
                dry(hour, from: hour.date, to: sunrise, inSun: false)
                dry(hour, from: sunrise, to: end, inSun: sunlit)
            }
            if let current, current.date >= hour.date, current.date < end, current.date < wettingBefore,
               let cause = cause(rained: current.isRaining, condenses: current.date < night.sunrise, spreadC: current.spreadC,
                                 cloudCover: current.cloudCover, windMS: current.windMS, tempC: current.tempC, settings: settings) {
                wetted(by: cause, at: current.date)
            }
            if let seen, seen.at >= hour.date, seen.at < end {
                if let cause = seen.cause {
                    if wet == nil { wetted(by: cause, at: seen.at) }
                } else {
                    wet = nil
                }
            }
        }
        if let wet { spells.append(WetFly(cause: wet.cause, since: wet.since, dryBy: nil)) }
        return spells
    }

    /// A diary answer as the walk reads it: when it was given, and what had wet the fly.
    private struct Seen {
        let at: Date
        /// Nil when the fly was found dry.
        let cause: Trigger?

        init?(_ observation: DewObservation?) {
            guard let observation else { return nil }
            at = observation.at
            switch observation.kind {
            case .dry: cause = nil
            case .lightDew, .wet: cause = .dew
            case .frost: cause = .frost
            case .rain: cause = .rain
            case .notChecked: return nil
            }
        }
    }

    private static func cause(
        rained: Bool, condenses: Bool, spreadC: Double, cloudCover: Double, windMS: Double, tempC: Double, settings: Settings
    ) -> Trigger? {
        if rained { return .rain }
        guard condenses, FlyEngine.condenses(spreadC: spreadC, cloudCover: cloudCover, windMS: windMS, settings: settings) else {
            return nil
        }
        return FlyEngine.isFrostAir(tempC) ? .frost : .dew
    }
}
