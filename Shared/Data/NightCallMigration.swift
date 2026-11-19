// NightCallMigration.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// Gives nights kept by a version that sealed no calls the call they would have had: the last
/// forecast fetched before the anchor, with the settings in force at the anchor. Runs once on
/// each device, then removes what only those versions kept.
enum NightCallMigration {
    private static let doneKey = "sealsNightCalls"

    static func run(defaults: UserDefaults = SettingsStore().defaults, directory: URL = AppGroup.applicationSupport, now: Date = .now) {
        guard !defaults.bool(forKey: doneKey) else { return }
        let log = defaults.data(forKey: "settingsLog").flatMap { try? JSONDecoder().decode(SettingsLog.self, from: $0) }
        let current = SettingsStore(defaults: defaults).settings
        let call = { (fetches: [NightForecast]) in
            Self.call(from: fetches, now: now) { log?.settings(at: $0) ?? current }
        }

        let cache = ForecastCache(directory: directory)
        let nights = Dictionary(grouping: cache.store.load() ?? []) { "\($0.location.name)|\(ForecastCache.date(of: $0))" }
        for call in nights.values.compactMap(call) { _ = cache.keep(call) }

        let diaryStore = Store<DewDiary>(url: directory.appending(path: "dewdiary.json"))
        if var diary = diaryStore.load() {
            for call in diary.nights.filter({ $0.call == nil }).compactMap({ call($0.forecasts) }) { diary.setCall(call) }
            diaryStore.save(diary)
        }

        defaults.removeObject(forKey: "settingsLog")
        try? FileManager.default.removeItem(at: directory.appending(path: "found.json"))
        defaults.set(true, forKey: doneKey)
    }

    /// The call of a night whose anchor has passed, from the fetches kept for it.
    static func call(from fetches: [NightForecast], now: Date, settingsAt: (Date) -> Settings) -> NightCall? {
        fetches
            .filter { $0.fetchedAt < NightWindow.anchor(of: $0) && NightWindow.anchor(of: $0) <= now }
            .max { $0.fetchedAt < $1.fetchedAt }
            .map { NightCall($0, settings: settingsAt(NightWindow.anchor(of: $0))) }
    }

    /// The settings history those versions kept, to judge a night by the settings of its evening.
    private struct SettingsLog: Decodable {
        struct Change: Decodable {
            let at: Date
            let settings: Settings
        }

        let changes: [Change]

        func settings(at date: Date) -> Settings? {
            changes.last { $0.at <= date }?.settings
        }
    }
}
