// SyncTests.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
import Testing
@testable import Zeltwetter_Watch_App

private typealias F = Fixture

struct SyncRulesTests {
    private let lake = CampLocation(name: "Lost Lake", latitude: 39.9, longitude: -105.6, timeZoneID: "America/Denver")
    private let ridge = CampLocation(name: "Ridge", latitude: 40.1, longitude: -105.7, timeZoneID: "America/Denver")
    private let night = NightDate(year: 2026, month: 7, day: 1)

    private var start: SyncedState {
        SyncedState(camps: Camps(), settings: Settings(), units: DisplayUnits(fahrenheit: false, mph: false), changedAt: [:])
    }

    private func changing(_ state: SyncedState, at hour: Int, _ change: (inout SyncedState) -> Void) -> SyncedState {
        var changed = state
        change(&changed)
        return SyncRules.stamping(changed, changedFrom: state, at: F.at(0, hour))
    }

    @Test func editsMadeApartOnBothDevicesAllSurvive() {
        let phone = changing(start, at: 18) { $0.camps.add(lake) }
        let watch = changing(start, at: 19) {
            $0.settings.rainChance = 0.4
            $0.units.mph = true
        }
        let merged = SyncRules.merge(watch, into: phone)
        #expect(merged.camps.saved == [lake])
        #expect(merged.settings.rainChance == 0.4)
        #expect(merged.units.mph)
        #expect(SyncRules.merge(phone, into: watch) == merged)
    }

    @Test func theLaterChangeToAnItemWins() {
        let phone = changing(start, at: 18) { $0.settings.rainChance = 0.3 }
        let watch = changing(start, at: 19) { $0.settings.rainChance = 0.5 }
        #expect(SyncRules.merge(watch, into: phone).settings.rainChance == 0.5)
        #expect(SyncRules.merge(phone, into: watch).settings.rainChance == 0.5)
    }

    @Test func aRemovalStaysRemoved() {
        let both = changing(start, at: 17) { $0.camps.add(lake) }
        let phone = changing(both, at: 18) { $0.camps.remove(named: lake.name) }
        let watch = changing(both, at: 19) { $0.camps.add(ridge) }
        #expect(SyncRules.merge(watch, into: phone).camps.saved == [ridge])
        #expect(SyncRules.merge(phone, into: watch).camps.saved == [ridge])
    }

    @Test func aTurnedOffBagRatingSyncs() {
        let both = changing(start, at: 17) { $0.settings.bagRatingC = 5 }
        let phone = changing(both, at: 18) { $0.settings.bagRatingC = nil }
        #expect(SyncRules.merge(phone, into: both).settings.bagRatingC == nil)
    }

    @Test func aNightWhoseCampWasRemovedIsDropped() {
        let both = changing(start, at: 17) { $0.camps.add(lake) }
        let phone = changing(both, at: 18) { $0.camps.remove(named: lake.name) }
        let watch = changing(both, at: 19) { $0.camps.plan(lake.name, on: night) }
        let merged = SyncRules.merge(watch, into: phone)
        #expect(merged.camps.saved.isEmpty)
        #expect(merged.camps.trip.isEmpty)
    }

    @Test func undatedItemsSettleTheSameOnBothSides() {
        var phone = start, watch = start
        phone.camps.add(lake)
        phone.settings.rainChance = 0.3
        watch.camps.add(ridge)
        watch.settings.rainChance = 0.5
        let merged = SyncRules.merge(watch, into: phone)
        #expect(Set(merged.camps.saved.map(\.name)) == [lake.name, ridge.name])
        #expect(SyncRules.merge(phone, into: watch).settings == merged.settings)
    }

    @Test func mergingAgainChangesNothing() {
        let phone = changing(start, at: 18) { $0.camps.add(lake) }
        let watch = changing(start, at: 19) { $0.camps.add(ridge) }
        let merged = SyncRules.merge(watch, into: phone)
        #expect(SyncRules.merge(watch, into: merged) == merged)
        #expect(SyncRules.merge(merged, into: merged) == merged)
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
        #expect(model.sharedState.changedAt.keys.sorted() == ["camp/" + lake.name])
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
        var changed = model.sharedState
        changed.camps = camps
        changed.settings = settings
        changed.units = DisplayUnits(fahrenheit: true, mph: true)
        let received = SyncRules.stamping(changed, changedFrom: model.sharedState, at: .now.addingTimeInterval(60))

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
