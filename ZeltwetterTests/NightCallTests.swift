// NightCallTests.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
import Testing
@testable import Zeltwetter_Watch_App

private typealias F = Fixture

private func fetched(_ night: NightForecast, at date: Date) -> NightForecast {
    NightForecast(location: night.location, fetchedAt: date, sunset: night.sunset, sunrise: night.sunrise, hours: night.hours)
}

private let metric = DisplayUnits(fahrenheit: false, mph: false)

struct NightCallTests {
    @Test func dewThatClearsBeforeTheAnchorIsNotInTheCall() {
        let earlyDew = F.night { d in d < F.at(0, 21) ? F.hour(d, temp: 12, dewPoint: 10, wind: 1) : F.hour(d) }
        #expect(FlyEngine.evaluate(earlyDew, settings: Settings()).condensation != nil)
        let call = NightCall.seal(fetched(earlyDew, at: F.at(0, 21, 50)), settings: Settings())
        #expect(call?.verdict.condensation == nil)
        #expect(call?.verdict.flyOn == false)
    }

    @Test func dewFromTheAnchorOnIsInTheCall() {
        let lateDew = F.night { d in d < F.at(0, 22) ? F.hour(d) : F.hour(d, temp: 12, dewPoint: 10, wind: 1) }
        let call = NightCall.seal(fetched(lateDew, at: F.at(0, 21, 50)), settings: Settings())
        #expect(call?.verdict.condensation?.at == F.at(0, 22))
    }

    @Test func theEveningVerdictIsTheCallItBecomes() {
        let dew = F.night { d in d < F.at(0, 21) || d >= F.at(1, 2) ? F.hour(d, temp: 12, dewPoint: 10, wind: 1) : F.hour(d) }
        let forecast = fetched(dew, at: F.at(0, 21, 50))
        let evening = VerdictText(night: forecast, settings: Settings(), units: metric)
        #expect(evening.verdict == NightCall.seal(forecast, settings: Settings())?.verdict)
        #expect(evening.verdict.condensation?.at == F.at(1, 2))
    }

    @Test func aForecastFetchedAtOrAfterTheAnchorIsNotACall() {
        #expect(NightCall.seal(fetched(F.night(), at: F.at(0, 21, 59)), settings: Settings()) != nil)
        #expect(NightCall.seal(fetched(F.night(), at: F.at(0, 22)), settings: Settings()) == nil)
        #expect(NightCall.seal(fetched(F.night(), at: F.at(1, 0, 58)), settings: Settings()) == nil)
    }

    @Test func theCallKeepsItsSettings() {
        var wide = Settings()
        wide.dewSpreadC = 5
        let nearly = F.night { F.hour($0, temp: 12, dewPoint: 8, wind: 1) }
        let call = NightCall.seal(fetched(nearly, at: F.at(0, 21)), settings: wide)
        #expect(call?.settings == wide)
        #expect(call?.verdict.condensation != nil)
    }
}
