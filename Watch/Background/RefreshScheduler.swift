// RefreshScheduler.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
import WatchKit

/// Background refreshes: each one refetches an old forecast, samples the pressure at night,
/// and books the next. watchOS treats the date as a request and may run it later.
enum RefreshScheduler {
    static let identifier = "refresh"
    static let nightInterval: TimeInterval = 15 * 60
    static let dayInterval: TimeInterval = 3600

    @MainActor
    static func run(_ model: ForecastModel, pressure: PressureWatch, now: Date = .now) async {
        await model.refreshIfStale(now: now, inBackground: true)
        if model.preferences.pressureWatch {
            await pressure.check(night: model.night, verdict: model.verdict, now: now)
        }
        schedule(model)
    }

    @MainActor
    static func schedule(_ model: ForecastModel, now: Date = .now) {
        let date = nextDate(after: now, window: model.window, pressureWatch: model.preferences.pressureWatch)
        WKApplication.shared().scheduleBackgroundRefresh(withPreferredDate: date, userInfo: identifier as NSString) { _ in }
    }

    /// Every quarter hour through the night while the pressure is watched; otherwise hourly,
    /// and soon after sunset and after pack-by, when the complication moves to a new night.
    static func nextDate(after now: Date, window: NightWindow?, pressureWatch: Bool) -> Date {
        let soonest = now.addingTimeInterval(nightInterval)
        guard let window else { return now.addingTimeInterval(dayInterval) }
        if pressureWatch, now >= window.sunset, now < window.sunrise { return soonest }
        let marks = [window.sunset, window.packBy.addingTimeInterval(60)].filter { $0 > now }
        let next = min(now.addingTimeInterval(dayInterval), marks.min() ?? .distantFuture)
        return max(soonest, next)
    }
}
