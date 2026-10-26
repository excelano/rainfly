// DewLogTests.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

#if DEBUG
import Foundation
import Testing
@testable import Zeltwetter_Watch_App

private typealias F = Fixture

struct DewLogTests {
    private func refetched(_ night: NightForecast, after seconds: TimeInterval) -> NightForecast {
        NightForecast(location: night.location, fetchedAt: night.fetchedAt.addingTimeInterval(seconds), sunset: night.sunset, sunrise: night.sunrise, hours: night.hours)
    }

    @Test func eachFetchIsKeptOnceUnderItsNight() {
        var log = DewLog()
        let night = F.night()
        log.record(night)
        log.record(night)
        log.record(refetched(night, after: 3600))
        #expect(log.nights.count == 1)
        #expect(log.nights[0].forecasts.count == 2)
        #expect(log.nights[0].date == ForecastCache.date(of: night))
    }

    @Test func theMorningAsksOnceAboutTheNightsCamp() {
        var log = DewLog()
        let night = F.night()
        log.record(night)
        let camp = { (_: NightDate) in night.location.name }
        #expect(log.awaitingObservation(now: night.sunrise.addingTimeInterval(-60), campName: camp) == nil)
        let asked = log.awaitingObservation(now: night.sunrise.addingTimeInterval(3600), campName: camp)
        #expect(asked?.campName == night.location.name)
        #expect(log.awaitingObservation(now: night.sunrise.addingTimeInterval(3600)) { _ in "Elsewhere" } == nil)
        #expect(log.awaitingObservation(now: night.sunrise.addingTimeInterval(DewLog.answerWindow + 60), campName: camp) == nil)

        log.observe(DewObservation(kind: .dew, openSky: true, at: night.sunrise), campName: night.location.name, on: asked!.date)
        #expect(log.nights[0].observation?.kind == .dew)
        #expect(log.awaitingObservation(now: night.sunrise.addingTimeInterval(3600), campName: camp) == nil)
    }

    @Test func historyIsFetchedAfterTheNightAndAgainOnceSettled() {
        var log = DewLog()
        let night = F.night()
        log.record(night)
        #expect(log.needingActuals(now: night.sunrise).isEmpty)
        #expect(log.needingActuals(now: night.sunrise.addingTimeInterval(DewLog.historyDelay + 60)).count == 1)

        let early = NightForecast(location: night.location, fetchedAt: night.sunrise.addingTimeInterval(3 * 3600), sunset: night.sunset, sunrise: night.sunrise, hours: night.hours)
        log.setActual(early, campName: night.location.name, on: log.nights[0].date)
        #expect(log.needingActuals(now: night.sunrise.addingTimeInterval(4 * 3600)).count == 1)

        let settled = NightForecast(location: night.location, fetchedAt: night.sunrise.addingTimeInterval(DewLog.settledAfter + 60), sunset: night.sunset, sunrise: night.sunrise, hours: night.hours)
        log.setActual(settled, campName: night.location.name, on: log.nights[0].date)
        #expect(log.needingActuals(now: night.sunrise.addingTimeInterval(DewLog.settledAfter + 3600)).isEmpty)
        #expect(log.needingActuals(now: night.sunrise.addingTimeInterval(DewLog.historyReach + 60)).isEmpty)
    }

    @Test func theReportComparesTheForecastWithTheHistory() {
        var log = DewLog()
        let pitched = F.night()
        log.record(pitched)
        let date = log.nights[0].date
        let dewy = F.dewyNight { F.hour($0) }
        let history = NightForecast(location: pitched.location, fetchedAt: pitched.sunrise.addingTimeInterval(DewLog.settledAfter), sunset: dewy.sunset, sunrise: dewy.sunrise, hours: dewy.hours)
        log.setActual(history, campName: pitched.location.name, on: date)
        log.observe(DewObservation(kind: .dew, openSky: true, at: pitched.sunrise), campName: pitched.location.name, on: date)

        let rows = log.report(settings: Settings()).split(separator: "\n").map { $0.split(separator: ",", omittingEmptySubsequences: false).map(String.init) }
        #expect(rows.count == 2)
        let row = Dictionary(uniqueKeysWithValues: zip(rows[0], rows[1]))
        #expect(row["found"] == "dew")
        #expect(row["open_sky"] == "yes")
        #expect(row["forecast_wet"] == "dry")
        #expect(row["history_wet"] == "dew")
        #expect(row["forecasts"] == "1")
    }
}
#endif
