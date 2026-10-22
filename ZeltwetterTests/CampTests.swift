// CampTests.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
import Testing
@testable import Zeltwetter_Watch_App

private let lake = CampLocation(name: "Lost Lake", latitude: 39.9389, longitude: -105.6106, timeZoneID: "America/Denver")
private let ridge = CampLocation(name: "Ridge", latitude: 39.97, longitude: -105.65, timeZoneID: "America/Denver")

struct NightDateTests {
    @Test func stepsAcrossMonthsAndYears() {
        let date = NightDate(year: 2026, month: 12, day: 31)
        #expect(date.adding(days: 1) == NightDate(year: 2027, month: 1, day: 1))
        #expect(NightDate(year: 2026, month: 3, day: 1).adding(days: -1) == NightDate(year: 2026, month: 2, day: 28))
        #expect(date.adding(days: 3).days(since: date) == 3)
        #expect(date < date.adding(days: 1))
    }

    @Test func startsAtMidnightInTheCampsZone() {
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let start = NightDate(year: 2026, month: 7, day: 1).start(in: tokyo)
        #expect(tokyo.dateComponents([.month, .day, .hour], from: start) == DateComponents(month: 7, day: 1, hour: 0))
        #expect(NightDate(start, calendar: tokyo) == NightDate(year: 2026, month: 7, day: 1))
    }
}

struct CampsTests {
    private let july1 = NightDate(year: 2026, month: 7, day: 1)

    @Test func nightsWithoutAPlanAreHere() {
        var camps = Camps()
        camps.add(lake)
        #expect(camps.campName(on: july1) == CampLocation.hereName)
        camps.plan(lake.name, on: july1)
        #expect(camps.campName(on: july1) == lake.name)
        #expect(camps.campName(on: july1.adding(days: 1)) == CampLocation.hereName)
    }

    @Test func aNightHoldsOneCampAndHereClearsIt() {
        var camps = Camps()
        camps.add(lake)
        camps.add(ridge)
        camps.plan(ridge.name, on: july1.adding(days: 1))
        camps.plan(lake.name, on: july1)
        camps.plan(ridge.name, on: july1)
        #expect(camps.trip == [TripNight(date: july1, campName: ridge.name), TripNight(date: july1.adding(days: 1), campName: ridge.name)])
        camps.plan(CampLocation.hereName, on: july1)
        #expect(camps.trip.map(\.date) == [july1.adding(days: 1)])
    }

    @Test func namesStayUnique() {
        var camps = Camps()
        #expect(camps.add(lake).name == "Lost Lake")
        #expect(camps.add(lake).name == "Lost Lake 2")
        #expect(camps.add(lake).name == "Lost Lake 3")
        #expect(camps.add(CampLocation(name: "Here", latitude: 0, longitude: 0, timeZoneID: "UTC")).name == "Here 2")
        #expect(camps.add(CampLocation(name: "  ", latitude: 0, longitude: 0, timeZoneID: "UTC")).name == "Camp")
    }

    @Test func removingACampDropsItsNights() {
        var camps = Camps()
        camps.add(lake)
        camps.add(ridge)
        camps.plan(lake.name, on: july1)
        camps.plan(ridge.name, on: july1.adding(days: 1))
        camps.remove(named: lake.name)
        #expect(camps.saved == [ridge])
        #expect(camps.trip.map(\.campName) == [ridge.name])
    }

    @Test func pastNightsAreDropped() {
        var camps = Camps()
        camps.add(lake)
        camps.plan(lake.name, on: july1)
        camps.plan(lake.name, on: july1.adding(days: 1))
        camps.removeNights(before: july1.adding(days: 1))
        #expect(camps.trip.map(\.date) == [july1.adding(days: 1)])
    }

    @Test func roundTripsThroughTheStore() {
        var camps = Camps()
        camps.add(lake)
        camps.plan(lake.name, on: july1)
        let store = temporaryCamps()
        store.save(camps)
        #expect(store.load() == camps)
    }

    @Test func offlineZonesComeFromTheLongitude() {
        #expect(CampPlace.estimatedZone(longitude: -105.6).secondsFromGMT() == -7 * 3600)
        #expect(CampPlace.estimatedZone(longitude: 2.3).secondsFromGMT() == 0)
        #expect(CampPlace.estimatedZone(longitude: 172.6).secondsFromGMT() == 12 * 3600)
        let zone = CampPlace.estimatedZone(longitude: -105.6)
        #expect(TimeZone(identifier: zone.identifier)?.secondsFromGMT() == -7 * 3600)
    }
}

struct CoordinateEntryTests {
    @Test func startsFromTheCoordinateInDDM() {
        let entry = CoordinateEntry(latitude: 29.75205, longitude: -95.3742667)
        #expect(entry.latitude.text == "N 29° 45.123")
        #expect(entry.longitude.text == "W 095° 22.456")
    }

    @Test func fieldsWrapWithoutCarrying() {
        var entry = CoordinateEntry(latitude: 29.75205, longitude: -95.3742667)
        entry.adjust(.latOnes, by: 7)
        entry.adjust(.latHundredths, by: -2)
        entry.adjust(.lonMinutes, by: 3)
        entry.adjust(.lonHemisphere, by: 1)
        #expect(entry.latitude.text == "N 29° 45.920")
        #expect(entry.longitude.text == "E 095° 25.456")
        #expect(abs(entry.latitude.value - (29 + 45.920 / 60)) < 1e-12)
        entry.adjust(.lonDegrees, by: 85)
        #expect(entry.text(.lonDegrees) == "000")
    }

    @Test func polesClampIntoTheEditableRange() {
        let entry = CoordinateEntry(latitude: 90, longitude: -180)
        #expect(entry.latitude.text == "N 89° 59.999")
        #expect(entry.longitude.text == "W 179° 59.999")
    }

    @Test func crownCountsDetentsTheShortWayRound() {
        #expect(Crown.steps(from: 10, to: 13) == 3)
        #expect(Crown.steps(from: 13, to: 10) == -3)
        #expect(Crown.steps(from: 99, to: 0) == 1)
        #expect(Crown.steps(from: 0, to: 99) == -1)
    }
}

@MainActor
struct TripModelTests {
    let afternoon = Calendar.current.date(bySettingHour: 15, minute: 0, second: 0, of: .now)!
    private var tonight: NightDate { NightDate(afternoon, calendar: .current) }

    private func model(_ provider: FakeProvider, cache: ForecastCache = temporaryCache(), camps: Camps) -> ForecastModel {
        let store = temporaryCamps()
        store.save(camps)
        return ForecastModel(provider: provider, cache: cache, store: temporarySettings(), campStore: store) {
            CampLocation(name: CampLocation.hereName, latitude: 39.6, longitude: -105.9, timeZoneID: TimeZone.current.identifier)
        }
    }

    private func trip(_ nights: [(CampLocation, Int)]) -> Camps {
        var camps = Camps()
        camps.add(lake)
        camps.add(ridge)
        for (camp, offset) in nights { camps.plan(camp.name, on: tonight.adding(days: offset)) }
        return camps
    }

    @Test func tonightsTripCampIsShown() async {
        let provider = FakeProvider(fetchedAt: afternoon)
        let model = model(provider, camps: trip([(lake, 0)]))
        await model.refreshIfStale(now: afternoon)
        #expect(model.campName == lake.name)
        #expect(model.night?.location == lake)
        #expect(await provider.campsFetched == [lake.name])
    }

    @Test func aCampInAnotherZoneIsFetchedForItsOwnEvening() async {
        let provider = FakeProvider(fetchedAt: afternoon)
        let cache = temporaryCache()
        var camps = Camps()
        let hut = camps.add(CampLocation(name: "Hut", latitude: -43.6, longitude: 170.1, timeZoneID: "Pacific/Auckland"))
        camps.plan(hut.name, on: tonight)
        let model = model(provider, cache: cache, camps: camps)
        await model.refreshIfStale(now: afternoon)
        #expect(cache.night(at: hut.name, on: tonight) != nil)
    }

    @Test func showingHereClearsTonightsPlan() async {
        let provider = FakeProvider(fetchedAt: afternoon)
        let model = model(provider, camps: trip([(lake, 0), (ridge, 1)]))
        await model.show(CampLocation.hereName, now: afternoon)
        #expect(model.campName == CampLocation.hereName)
        #expect(model.camps.trip.map(\.campName) == [ridge.name])
        await model.show(ridge.name, now: afternoon)
        #expect(model.night?.location == ridge)
    }

    @Test func removingTheShownCampFallsBackToHere() async {
        let provider = FakeProvider(fetchedAt: afternoon)
        let model = model(provider, camps: trip([(lake, 0)]))
        await model.refreshIfStale(now: afternoon)
        await model.removeCamp(named: lake.name)
        #expect(model.camps.trip.isEmpty)
        #expect(model.camps.saved == [ridge])
    }

    @Test func pastNightsLeaveTheTrip() async {
        let provider = FakeProvider(fetchedAt: afternoon)
        let model = model(provider, camps: trip([(lake, -2), (ridge, 0)]))
        await model.refreshIfStale(now: afternoon)
        #expect(model.camps.trip.map(\.campName) == [ridge.name])
    }

    @Test func downloadFetchesNightsWithinAWeekOnce() async {
        let provider = FakeProvider(fetchedAt: afternoon)
        let model = model(provider, camps: trip([(lake, 1), (ridge, 2), (lake, ForecastModel.tripHorizon + 1)]))
        await model.downloadTrip(now: afternoon)
        #expect(model.camps.trip.prefix(2).allSatisfy { model.cachedNight($0) != nil })
        #expect(model.cachedNight(model.camps.trip[2]) == nil)
        #expect(model.downloadReport == "2 nights ready. Later nights download once they are a week out.")
        let fetched = await provider.campsFetched.filter { $0 != CampLocation.hereName }.count
        await model.downloadTrip(now: afternoon.addingTimeInterval(60))
        #expect(await provider.campsFetched.filter { $0 != CampLocation.hereName }.count == fetched)
    }
}
