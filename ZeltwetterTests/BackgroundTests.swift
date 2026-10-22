// BackgroundTests.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
import Testing
@testable import Zeltwetter_Watch_App

private typealias F = Fixture

private let flyOff = FlyEngine.evaluate(F.night(), settings: Settings())
private let flyOn = FlyEngine.evaluate(F.night { F.hour($0, chance: 0.5) }, settings: Settings())

struct PressureLogTests {
    private func log(_ readings: [(Int, Int, Double)]) -> PressureLog {
        var log = PressureLog()
        for (day, hour, hPa) in readings { log.record(PressureSample(date: F.at(day, hour), hPa: hPa)) }
        return log
    }

    @Test func aFallOfOneAndAHalfWithinThreeHoursIsFast() {
        #expect(log([(0, 22, 1012), (0, 23, 1011.5), (1, 1, 1010.5)]).isFallingFast)
        #expect(!log([(0, 22, 1012), (0, 23, 1011.5), (1, 1, 1010.6)]).isFallingFast)
    }

    @Test func aSlowFallIsNot() {
        #expect(!log([(0, 21, 1012), (1, 0, 1011), (1, 3, 1010)]).isFallingFast)
        #expect(!log([(0, 21, 1012)]).isFallingFast)
    }

    @Test func readingsOlderThanTwelveHoursAreDropped() {
        let log = log([(0, 12, 1015), (0, 20, 1014), (1, 1, 1013)])
        #expect(log.samples.map(\.hPa) == [1014, 1013])
    }

    @Test func warnsOnceANightAndOnlyWithTheFlyOff() {
        var log = log([(0, 22, 1012), (1, 0, 1010)])
        #expect(log.shouldWarn(verdict: flyOff, nightStart: F.sunset))
        #expect(!log.shouldWarn(verdict: flyOn, nightStart: F.sunset))
        log.warnedAt = F.at(1, 0)
        #expect(!log.shouldWarn(verdict: flyOff, nightStart: F.sunset))
        #expect(log.shouldWarn(verdict: flyOff, nightStart: F.sunset.addingTimeInterval(86_400)))
    }
}

@MainActor
struct PressureWatchTests {
    private final class Recorder {
        var readings: [Double]
        var warnings: [String] = []
        init(_ readings: [Double]) { self.readings = readings }
    }

    private func watch(_ recorder: Recorder) -> PressureWatch {
        let store = Store<PressureLog>(url: FileManager.default.temporaryDirectory.appending(path: "zeltwetter-pressure-\(UUID().uuidString).json"))
        return PressureWatch(store: store, sample: { recorder.readings.isEmpty ? nil : recorder.readings.removeFirst() }) {
            recorder.warnings.append($0)
        }
    }

    @Test func samplesOnlyDuringTheNight() async {
        let recorder = Recorder([1012, 1012])
        let watch = watch(recorder)
        await watch.check(night: F.night(), verdict: flyOff, now: F.at(0, 19))
        await watch.check(night: F.night(), verdict: flyOff, now: F.at(1, 7))
        #expect(recorder.readings.count == 2)
        #expect(watch.store.load() == nil)
    }

    @Test func warnsWhenPressureFallsWithTheFlyOff() async {
        let recorder = Recorder([1012, 1011, 1010, 1009])
        let watch = watch(recorder)
        for hour in [22, 23] { await watch.check(night: F.night(), verdict: flyOff, now: F.at(0, hour)) }
        #expect(recorder.warnings.isEmpty)
        for hour in [0, 1] { await watch.check(night: F.night(), verdict: flyOff, now: F.at(1, hour)) }
        #expect(recorder.warnings == [PressureWatch.message])
        #expect(watch.store.load()?.samples.count == 4)
    }

    @Test func staysQuietWithTheFlyOn() async {
        let recorder = Recorder([1012, 1009])
        let watch = watch(recorder)
        await watch.check(night: F.night(), verdict: flyOn, now: F.at(0, 22))
        await watch.check(night: F.night(), verdict: flyOn, now: F.at(1, 0))
        #expect(recorder.warnings.isEmpty)
    }
}

struct RefreshScheduleTests {
    private let window = NightWindow(F.night(), packByMinutes: 8 * 60)

    @Test func quarterHourlyThroughTheWatchedNight() {
        #expect(RefreshScheduler.nextDate(after: F.at(0, 23), window: window, pressureWatch: true) == F.at(0, 23, 15))
        #expect(RefreshScheduler.nextDate(after: F.at(0, 23), window: window, pressureWatch: false) == F.at(1, 0))
    }

    @Test func soonAfterSunsetAndPackBy() {
        #expect(RefreshScheduler.nextDate(after: F.at(0, 20), window: window, pressureWatch: true) == F.sunset)
        #expect(RefreshScheduler.nextDate(after: F.at(0, 20, 25), window: window, pressureWatch: true) == F.at(0, 20, 40))
        #expect(RefreshScheduler.nextDate(after: F.at(1, 7, 30), window: window, pressureWatch: true) == F.at(1, 8, 1))
    }

    @Test func hourlyOtherwise() {
        #expect(RefreshScheduler.nextDate(after: F.at(1, 10), window: window, pressureWatch: true) == F.at(1, 11))
        #expect(RefreshScheduler.nextDate(after: F.at(1, 10), window: nil, pressureWatch: true) == F.at(1, 11))
    }
}

@MainActor
struct BackgroundRefreshTests {
    @Test func backgroundUsesTheLastPositionForHere() async {
        let afternoon = Calendar.current.date(bySettingHour: 15, minute: 0, second: 0, of: .now)!
        let provider = FakeProvider(fetchedAt: afternoon)
        let cache = temporaryCache()
        let here = CampLocation(name: CampLocation.hereName, latitude: 39.6, longitude: -105.9, timeZoneID: TimeZone.current.identifier)
        await ForecastModel(provider: provider, cache: cache, store: temporarySettings(), campStore: temporaryCamps()) { here }
            .refreshIfStale(now: afternoon)

        let model = ForecastModel(provider: provider, cache: cache, store: temporarySettings(), campStore: temporaryCamps()) {
            throw ForecastError.noLocation
        }
        await model.refreshIfStale(now: afternoon.addingTimeInterval(ForecastModel.refreshAge + 60), inBackground: true)
        #expect(await provider.fetches == 2)
        #expect(model.problem == nil)
        #expect(model.night?.location == here)
    }
}
