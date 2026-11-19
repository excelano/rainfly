// NightCallMigrationTests.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
import Testing
@testable import Zeltwetter_Watch_App

private typealias F = Fixture

private func fetched(_ date: Date, _ night: NightForecast = F.night()) -> NightForecast {
    NightForecast(location: night.location, fetchedAt: date, sunset: night.sunset, sunrise: night.sunrise, hours: night.hours)
}

struct NightCallMigrationTests {
    private let july1 = NightDate(year: 2026, month: 7, day: 1)
    private let directory = FileManager.default.temporaryDirectory.appending(path: "zeltwetter-\(UUID().uuidString)")
    private let defaults: UserDefaults

    init() {
        let suite = "migration-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
    }

    /// The settings history as the earlier versions kept it: `evening` until `changedAt`, then the defaults.
    private func keepLog(evening: Settings, changedAt: Date) throws {
        let json = { (settings: Settings) in try JSONSerialization.jsonObject(with: JSONEncoder().encode(settings)) }
        let changes: [[String: Any]] = [
            ["at": Date.distantPast.timeIntervalSinceReferenceDate, "settings": try json(evening)],
            ["at": changedAt.timeIntervalSinceReferenceDate, "settings": try json(Settings())],
        ]
        defaults.set(try JSONSerialization.data(withJSONObject: ["changes": changes]), forKey: "settingsLog")
    }

    private var call: NightCall? {
        ForecastCache(directory: directory).fetches(at: F.camp.name, on: july1, settings: Settings())?.call
    }

    @Test func aCachedNightGetsTheCallOfItsLastForecastBeforeTheAnchor() throws {
        var wide = Settings()
        wide.dewSpreadC = 5
        try keepLog(evening: wide, changedAt: F.at(1, 6))
        let nearly = F.night { F.hour($0, temp: 12, dewPoint: 8, wind: 1) }
        Store<[NightForecast]>(url: directory.appending(path: "forecasts.json"))
            .save([fetched(F.at(0, 21, 30), nearly), fetched(F.at(1, 5), nearly)])

        NightCallMigration.run(defaults: defaults, directory: directory, now: F.at(1, 7))
        #expect(call?.forecast.fetchedAt == F.at(0, 21, 30))
        #expect(call?.settings == wide)
        #expect(call?.verdict.condensation != nil)
        #expect(defaults.data(forKey: "settingsLog") == nil)
    }

    @Test func aDiaryNightGetsItsCallAndOneFirstFetchedAfterTheAnchorGetsNone() {
        var diary = DewDiary()
        for date in [F.at(0, 17), F.at(0, 21, 30), F.at(0, 23)] { diary.record(fetched(date)) }
        let late = CampLocation(name: "Late", latitude: F.camp.latitude, longitude: F.camp.longitude, timeZoneID: F.camp.timeZoneID)
        diary.record(NightForecast(location: late, fetchedAt: F.at(1, 0, 58), sunset: F.sunset, sunrise: F.sunrise, hours: F.night().hours))
        let store = Store<DewDiary>(url: directory.appending(path: "dewdiary.json"))
        store.save(diary)

        NightCallMigration.run(defaults: defaults, directory: directory, now: F.at(2, 9))
        let migrated = store.load()
        #expect(migrated?.night(campName: F.camp.name, on: july1)?.call?.forecast.fetchedAt == F.at(0, 21, 30))
        #expect(migrated?.night(campName: "Late", on: july1)?.call == nil)
        #expect(migrated?.night(campName: F.camp.name, on: july1)?.forecasts.count == 3)
    }

    @Test func tonightIsLeftToSealAtItsAnchor() {
        Store<[NightForecast]>(url: directory.appending(path: "forecasts.json")).save([fetched(F.at(0, 19))])
        NightCallMigration.run(defaults: defaults, directory: directory, now: F.at(0, 20))
        #expect(ForecastCache(directory: directory).callStore.load() ?? [] == [])
    }

    @Test func itRunsOnceAndClearsWhatOnlyEarlierVersionsKept() throws {
        let found = directory.appending(path: "found.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("[]".utf8).write(to: found)
        NightCallMigration.run(defaults: defaults, directory: directory, now: F.at(1, 7))
        #expect(!FileManager.default.fileExists(atPath: found.path))

        Store<[NightForecast]>(url: directory.appending(path: "forecasts.json")).save([fetched(F.at(0, 21, 30))])
        NightCallMigration.run(defaults: defaults, directory: directory, now: F.at(1, 7))
        #expect(ForecastCache(directory: directory).callStore.load() ?? [] == [])
    }
}
