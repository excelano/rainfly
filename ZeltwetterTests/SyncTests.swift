// SyncTests.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
import Testing
@testable import Zeltwetter_Watch_App

private typealias F = Fixture

struct SyncRulesTests {
    private func state(at modifiedAt: Date, rain: Double = 0.2) -> SyncedState {
        var settings = Settings()
        settings.rainChance = rain
        return SyncedState(camps: Camps(), settings: settings, units: DisplayUnits(fahrenheit: false, mph: false), modifiedAt: modifiedAt)
    }

    @Test func theNewerStateWinsInEitherOrder() {
        let older = state(at: F.at(0, 18)), newer = state(at: F.at(0, 19), rain: 0.4)
        #expect(SyncRules.adopts(newer, over: older))
        #expect(!SyncRules.adopts(older, over: newer))
        #expect(!SyncRules.adopts(state(at: F.at(0, 18), rain: 0.4), over: older))
    }

    @Test func aNightIsKeptUnlessANewerFetchIsCached() {
        let cached = F.night()
        let newer = NightForecast(location: cached.location, fetchedAt: cached.fetchedAt.addingTimeInterval(600), sunset: cached.sunset, sunrise: cached.sunrise, hours: cached.hours)
        #expect(SyncRules.keeps(cached, over: nil))
        #expect(SyncRules.keeps(newer, over: cached))
        #expect(!SyncRules.keeps(cached, over: newer))
        #expect(!SyncRules.keeps(cached, over: cached))
    }

    @Test func hereNightsAreNeverSent() {
        let night = F.night()
        let here = CampLocation(name: CampLocation.hereName, latitude: 1, longitude: 2, timeZoneID: night.location.timeZoneID)
        let hereNight = NightForecast(location: here, fetchedAt: night.fetchedAt, sunset: night.sunset, sunrise: night.sunrise, hours: night.hours)
        #expect(SyncRules.sends(night))
        #expect(!SyncRules.sends(hereNight))
        #expect(!SyncRules.keeps(hereNight, over: nil))
    }

    @Test func thePhoneStandsDownOnlyWhileTheWatchWatches() {
        #expect(SyncRules.phoneStandsDown(watchAppInstalled: true, watchPressureWatch: true))
        #expect(!SyncRules.phoneStandsDown(watchAppInstalled: true, watchPressureWatch: false))
        #expect(!SyncRules.phoneStandsDown(watchAppInstalled: false, watchPressureWatch: true))
        #expect(!SyncRules.phoneStandsDown(watchAppInstalled: false, watchPressureWatch: false))
    }
}

@MainActor
struct SyncModelTests {
    let here = CampLocation(name: CampLocation.hereName, latitude: 39.6, longitude: -105.9, timeZoneID: TimeZone.current.identifier)
    let lake = CampLocation(name: "Lost Lake", latitude: 39.9, longitude: -105.6, timeZoneID: TimeZone.current.identifier)
    let afternoon = Calendar.current.date(bySettingHour: 15, minute: 0, second: 0, of: .now)!

    private func model(_ provider: FakeProvider, cache: ForecastCache = temporaryCache()) -> ForecastModel {
        ForecastModel(provider: provider, cache: cache, store: temporarySettings(), campStore: temporaryCamps()) { [here] in here }
    }

    @Test func aLocalChangeIsAnnouncedAndDated() {
        let model = model(FakeProvider(fetchedAt: afternoon))
        var announced = 0
        model.sharedStateChanged = { announced += 1 }
        model.addCamp(lake)
        #expect(announced == 1)
        #expect(model.sharedState.modifiedAt > .distantPast)
        model.preferences.pressureWatch.toggle()
        #expect(announced == 2)
    }

    @Test func aReceivedStateReplacesTheSharedPartsOnly() async {
        let model = model(FakeProvider(fetchedAt: afternoon))
        model.preferences.pressureWatch = false
        var announced = 0
        model.sharedStateChanged = { announced += 1 }
        var camps = Camps()
        camps.add(lake)
        var settings = Settings()
        settings.rainChance = 0.5
        let received = SyncedState(camps: camps, settings: settings, units: DisplayUnits(fahrenheit: true, mph: true), modifiedAt: .now.addingTimeInterval(60))

        #expect(await model.apply(received))
        #expect(model.camps == camps)
        #expect(model.settings.rainChance == 0.5)
        #expect(model.preferences.units.fahrenheit)
        #expect(!model.preferences.pressureWatch)
        #expect(model.sharedState == received)
        #expect(announced == 0)
        #expect(!(await model.apply(received)))
    }

    @Test func aReceivedNightIsCachedAndAnOlderOneIgnored() {
        let cache = temporaryCache()
        let model = model(FakeProvider(fetchedAt: afternoon), cache: cache)
        let night = F.night()
        model.receive(night)
        let date = ForecastCache.date(of: night)
        #expect(cache.night(at: night.location.name, on: date) == night)
        let older = NightForecast(location: night.location, fetchedAt: night.fetchedAt.addingTimeInterval(-600), sunset: night.sunset, sunrise: night.sunrise, hours: [])
        model.receive(older)
        #expect(cache.night(at: night.location.name, on: date) == night)
    }

    @Test func onlySavedCampsNightsAreHandedOn() async {
        let provider = FakeProvider(fetchedAt: afternoon)
        let model = model(provider)
        var handed: [String] = []
        model.nightFetched = { handed.append($0.location.name) }
        await model.refreshIfStale(now: afternoon)
        #expect(handed.isEmpty)
        model.addCamp(lake)
        await model.show(lake.name, now: afternoon)
        #expect(handed == [lake.name])
    }
}
