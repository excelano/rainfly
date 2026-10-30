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
/// are over get their hours from WeatherKit's history. With sharing on, answered nights are
/// sent to Excelano as they are answered and again as their history arrives.
@MainActor
@Observable
final class DiaryRecorder {
    private(set) var diary: DewDiary
    /// Why the last attempt to share failed, until one succeeds.
    private(set) var shareProblem: String?
    private(set) var isSharing = false
    @ObservationIgnored private let uploader = DiaryUploader()
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
        DiaryReminder.cancel()
        Task { await share() }
    }

    /// Removes the night from the diary, and its shared copy from Excelano's database.
    func remove(_ night: DiaryNight) {
        diary.remove(campName: night.campName, on: night.date)
        save()
        if let shared = night.shared {
            Task {
                do { try await uploader.delete([shared.recordName]) } catch { shareProblem = DiaryUploader.describe(error) }
            }
        }
    }

    /// The last time a night was sent, for the diary screen.
    var lastShared: Date? {
        diary.nights.compactMap(\.shared?.at).max()
    }

    var sharedCount: Int {
        diary.nights.filter { $0.shared != nil }.count
    }

    /// Sends what needs sending, while the diary and sharing are both on.
    func share() async {
        let preferences = model.preferences
        guard preferences.dewDiary, preferences.shareDiary, !isSharing else { return }
        let diaryID = preferences.diaryID ?? UUID()
        if preferences.diaryID == nil { model.preferences.diaryID = diaryID }
        let due = diary.needingShare().compactMap { night in
            SharedNight(night, diaryID: diaryID, settings: model.settings, appVersion: Self.appVersion).map { (night, $0) }
        }
        guard !due.isEmpty else { return }
        isSharing = true
        defer { isSharing = false }
        let stale = due.compactMap { night, shared in night.shared.map(\.recordName).flatMap { $0 == shared.recordName ? nil : $0 } }
        do {
            try await uploader.send(due.map(\.1), deleting: stale)
            let now = Date.now
            for (night, shared) in due {
                diary.markShared(SharedMark(recordName: shared.recordName, at: now), campName: night.campName, on: night.date)
            }
            shareProblem = nil
            save()
        } catch {
            shareProblem = DiaryUploader.describe(error)
        }
    }

    /// Deletes every night this phone shared from Excelano's database; the diary stays.
    func deleteShared() async {
        let names = diary.nights.compactMap(\.shared?.recordName)
        do {
            try await uploader.delete(names)
            for night in diary.nights where night.shared != nil {
                diary.markShared(nil, campName: night.campName, on: night.date)
            }
            shareProblem = nil
            save()
        } catch {
            shareProblem = DiaryUploader.describe(error)
        }
    }

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    func fillHistory(now: Date = .now) async {
        guard model.preferences.dewDiary else { return }
        for night in diary.needingHistory(now: now) {
            guard let camp = night.forecasts.last?.location else { continue }
            do {
                let history = try await model.history(at: camp, on: night.date)
                diary.setHistory(history, campName: night.campName, on: night.date)
                save()
                await share()
            } catch {
                logger.error("History for \(night.campName, privacy: .public) failed: \(error, privacy: .public)")
            }
        }
    }

    private func record(_ night: NightForecast) {
        guard model.preferences.dewDiary else { return }
        diary.record(night)
        save()
        let date = ForecastCache.date(of: night)
        if model.preferences.diaryReminder, date == model.nightDate(), night.location.name == model.camps.campName(on: date) {
            Task { await DiaryReminder.schedule(after: night, packByMinutes: model.settings.packByMinutes) }
        }
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
