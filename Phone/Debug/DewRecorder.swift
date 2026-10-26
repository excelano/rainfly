// DewRecorder.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

#if DEBUG
import Foundation
import Observation
import os
import SwiftUI

private let logger = Logger(subsystem: "com.excelano.zeltwetter", category: "dewlog")

/// Keeps the dew log in a Debug build: every fetch goes in as it arrives, the morning card
/// adds what was found, and each time the app comes forward the nights that are over get
/// their hours from WeatherKit's history. Every save rewrites dewlog-report.csv beside it.
@MainActor
@Observable
final class DewRecorder {
    private(set) var log: DewLog
    @ObservationIgnored private let store = Store<DewLog>(name: "dewlog")
    @ObservationIgnored private let model: ForecastModel

    init(model: ForecastModel) {
        self.model = model
        log = store.load() ?? DewLog()
        model.anyNightFetched = { [weak self] night in self?.record(night) }
    }

    func observe(_ kind: DewObservation.Kind, openSky: Bool, night: DewLogNight) {
        log.observe(DewObservation(kind: kind, openSky: openSky, at: .now), campName: night.campName, on: night.date)
        save()
    }

    func fillActuals(now: Date = .now) async {
        for night in log.needingActuals(now: now) {
            guard let camp = night.forecasts.last?.location else { continue }
            do {
                let actual = try await model.history(at: camp, on: night.date)
                log.setActual(actual, campName: night.campName, on: night.date)
                save()
            } catch {
                logger.error("History for \(night.campName, privacy: .public) failed: \(error, privacy: .public)")
            }
        }
    }

    private func record(_ night: NightForecast) {
        log.record(night)
        save()
    }

    /// The log, and beside it the report it reads as, with the thresholds in use now.
    private func save() {
        store.save(log)
        let report = store.url.deletingLastPathComponent().appending(path: "dewlog-report.csv")
        do {
            try log.report(settings: model.settings).write(to: report, atomically: true, encoding: .utf8)
        } catch {
            logger.error("Writing the report failed: \(error, privacy: .public)")
        }
    }
}

extension EnvironmentValues {
    @Entry var dewRecorder: DewRecorder?
}
#endif
