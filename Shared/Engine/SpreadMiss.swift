// SpreadMiss.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// Why dew or frost did not form over a night's hours: the one condition that was missing.
enum SpreadMiss: Equatable, Sendable {
    /// The air never got close enough to its dew point; the closest gap it reached.
    case tooDry(closestC: Double)
    case cloudy, windy, cloudyOrWindy
    /// Clear and calm with the gap reached, but on the other side of the frost line.
    case otherSideOfFrostLine

    /// Nil when the night has no hours or the check would fire.
    static func of(_ trigger: Trigger, hours: [HourSample], settings: Settings) -> SpreadMiss? {
        guard let closest = hours.map(\.spreadC).min() else { return nil }
        let close = hours.filter { $0.spreadC <= settings.dewSpreadC }
        guard !close.isEmpty else { return .tooDry(closestC: closest) }
        let isCloudy = { (hour: HourSample) in hour.cloudCover >= settings.clearSky }
        let isWindy = { (hour: HourSample) in hour.windMS >= settings.calmWindMS }
        let open = close.filter { !isCloudy($0) && !isWindy($0) }
        if !open.isEmpty {
            let rightSide = open.contains { FlyEngine.isFrostAir($0.tempC) == (trigger == .frost) }
            return rightSide ? nil : .otherSideOfFrostLine
        }
        switch (close.contains(where: isCloudy), close.contains(where: isWindy)) {
        case (true, false): return .cloudy
        case (false, true): return .windy
        default: return .cloudyOrWindy
        }
    }
}
