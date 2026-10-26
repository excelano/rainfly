// DiaryRecorder.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
import Observation
import os
import SwiftUI

private let logger = Logger(subsystem: "com.excelano.zeltwetter", category: "diary")

/// Keeps the dew diary while it is switched on: every fetch goes in as it arrives, the
/// morning question adds what was found, and each time the app comes forward the nights that
/// are over get their hours from WeatherKit's history.
@MainActor
@Observable
final class DiaryRecorder {
    private(set) var diary: DewDiary
    @ObservationIgnored private let store: Store<DewDiary>
    @ObservationIgnored private let model: ForecastModel

    init(model: ForecastModel, store: Store<DewDiary> = Store(name: "dewdiary")) {
        self.model = model
        self.store = store
        diary = store.load() ?? DewDiary()
        model.anyNightFetched = { [weak self] night in self?.record(night) }
    }

    func observe(_ kind: DewObservation.Kind, openSky: Bool, night: DiaryNight) {
        diary.observe(DewObservation(kind: kind, openSky: openSky, at: .now), campName: night.campName, on: night.date)
        save()
    }

    func remove(_ night: DiaryNight) {
        diary.remove(campName: night.campName, on: night.date)
        save()
    }

    func fillHistory(now: Date = .now) async {
        guard model.preferences.dewDiary else { return }
        for night in diary.needingHistory(now: now) {
            guard let camp = night.forecasts.last?.location else { continue }
            do {
                let history = try await model.history(at: camp, on: night.date)
                diary.setHistory(history, campName: night.campName, on: night.date)
                save()
            } catch {
                logger.error("History for \(night.campName, privacy: .public) failed: \(error, privacy: .public)")
            }
        }
    }

    private func record(_ night: NightForecast) {
        guard model.preferences.dewDiary else { return }
        diary.record(night)
        save()
    }

    private func save() {
        store.save(diary)
        #if DEBUG
        let report = store.url.deletingLastPathComponent().appending(path: "dewdiary-report.csv")
        do {
            try diary.report(settings: model.settings).write(to: report, atomically: true, encoding: .utf8)
        } catch {
            logger.error("Writing the report failed: \(error, privacy: .public)")
        }
        #endif
    }
}

extension EnvironmentValues {
    @Entry var diaryRecorder: DiaryRecorder?
}
