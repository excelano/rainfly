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
        var outcome: PressureWatch.Outcome?
        if model.preferences.pressureWatch {
            outcome = await pressure.check(night: model.night, verdict: model.verdict, now: now)
        }
        RefreshLog.record(pressureWatch: model.preferences.pressureWatch, pressure: outcome, fetchedAt: model.night?.fetchedAt, now: now)
        schedule(model)
    }

    @MainActor
    static func schedule(_ model: ForecastModel, now: Date = .now) {
        let date = RefreshTiming.nextDate(after: now, window: model.window, pressureWatch: model.preferences.pressureWatch)
        WKApplication.shared().scheduleBackgroundRefresh(withPreferredDate: date, userInfo: RefreshTiming.identifier as NSString) { _ in }
    }
}
