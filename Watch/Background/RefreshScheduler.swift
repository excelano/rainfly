// RefreshScheduler.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
import WatchKit

/// Background refreshes: each one refetches an old forecast, samples the pressure at night,
/// and books the next.
enum RefreshScheduler {
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
        let date = RefreshTiming.nextDate(after: now, window: model.window, pressureWatch: model.preferences.pressureWatch)
        WKApplication.shared().scheduleBackgroundRefresh(withPreferredDate: date, userInfo: RefreshTiming.identifier as NSString) { _ in }
    }
}
