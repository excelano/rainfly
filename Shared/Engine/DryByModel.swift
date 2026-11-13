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
