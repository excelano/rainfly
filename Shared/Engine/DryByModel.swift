// DryByModel.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

struct DryByModel: Codable, Equatable, Sendable {
    var dewToDry = 46.0
    var frostToDry = 69.0
    var rainToDry = 92.0
    var windGain = 0.25
    var sunGain = 2.0
    /// The local hour after which the estimate gives up.
    var cutoffHour = 12

    func dryBy(_ night: NightForecast, frost: Bool, calendar: Calendar) -> Date? {
        guard let cutoff = calendar.date(bySettingHour: cutoffHour, minute: 0, second: 0, of: night.sunrise) else {
            return nil
        }
        let sunlit = night.polar != .polarNight
        var left = frost ? frostToDry : dewToDry
        for hour in night.hours.sorted(by: { $0.date < $1.date })
        where hour.date.addingTimeInterval(3600) > night.sunrise && hour.date < cutoff {
            let start = max(hour.date, night.sunrise)
            let hours = min(hour.date.addingTimeInterval(3600), cutoff).timeIntervalSince(start) / 3600
            let rate = dryingRate(hour, sunlit: sunlit)
            if rate * hours >= left {
                let dry = start.addingTimeInterval(left / rate * 3600)
                return Date(timeIntervalSinceReferenceDate: (dry.timeIntervalSinceReferenceDate / 900).rounded(.up) * 900)
            }
            left -= rate * hours
        }
        return nil
    }

    func toDry(_ cause: Trigger) -> Double {
        switch cause {
        case .frost: frostToDry
        case .dew: dewToDry
        default: rainToDry
        }
    }

    func dryingRate(_ hour: HourSample, sunlit: Bool) -> Double {
        let sun = sunlit ? 1 + sunGain * (1 - hour.cloudCover) : 1
        return Self.vapourPressureDeficit(tempC: hour.tempC, dewPointC: hour.dewPointC) * (1 + windGain * hour.windMS) * sun
    }

    static func vapourPressureDeficit(tempC: Double, dewPointC: Double) -> Double {
        max(0, saturationPressure(tempC) - saturationPressure(dewPointC))
    }

    private static func saturationPressure(_ tempC: Double) -> Double {
        6.112 * exp(17.62 * tempC / (243.12 + tempC))
    }
}
