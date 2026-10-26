// RefreshTiming.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// When to ask for the next background refresh, on either device. Both systems treat the
/// date as a request and may run it later, the phone far later than the watch.
enum RefreshTiming {
    static let identifier = "refresh"
    static let nightInterval: TimeInterval = 15 * 60
    static let dayInterval: TimeInterval = 3600

    /// Every quarter hour through the night while the pressure is watched; otherwise hourly,
    /// and soon after sunset and after pack-by, when the faces move to a new night.
    static func nextDate(after now: Date, window: NightWindow?, pressureWatch: Bool) -> Date {
        let soonest = now.addingTimeInterval(nightInterval)
        guard let window else { return now.addingTimeInterval(dayInterval) }
        if pressureWatch, now >= window.sunset, now < window.sunrise { return soonest }
        let marks = [window.sunset, window.packBy.addingTimeInterval(60)].filter { $0 > now }
        let next = min(now.addingTimeInterval(dayInterval), marks.min() ?? .distantFuture)
        return max(soonest, next)
    }
}
