// PhoneRefreshScheduler.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import BackgroundTasks
import Foundation
import os

private let log = Logger(subsystem: "com.excelano.zeltwetter", category: "refresh")

/// The phone's background refreshes, doing the watch's work: refetch an old forecast, sample
/// the pressure at night, book the next. iOS grants far fewer than are asked for, and none
/// after the app is force-quit, so the phone's pressure watch is an occasional check.
enum PhoneRefreshScheduler {
    @MainActor
    static func run(_ model: ForecastModel, pressure: PressureWatch, now: Date = .now) async {
        await model.refreshIfStale(now: now, inBackground: true)
        var outcome: PressureWatch.Outcome?
        if model.preferences.pressureWatch {
            outcome = await pressure.check(night: model.night, verdict: model.verdict, quiet: SettingsStore().watchWatchesPressure, now: now)
        }
        RefreshLog.record(pressureWatch: model.preferences.pressureWatch, pressure: outcome, fetchedAt: model.night?.fetchedAt, now: now)
        schedule(model)
    }

    @MainActor
    static func schedule(_ model: ForecastModel, now: Date = .now) {
        let request = BGAppRefreshTaskRequest(identifier: RefreshTiming.identifier)
        request.earliestBeginDate = RefreshTiming.nextDate(after: now, window: model.window, pressureWatch: model.preferences.pressureWatch)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            log.error("Booking a refresh failed: \(error, privacy: .public)")
        }
    }
}
