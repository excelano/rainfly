// MorningAndOvernightTests.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
import Testing
@testable import Zeltwetter_Watch_App

private typealias F = Fixture

private func fetched(_ night: NightForecast, at date: Date) -> NightForecast {
    NightForecast(location: night.location, fetchedAt: date, sunset: night.sunset, sunrise: night.sunrise, hours: night.hours)
}

private func plain(_ string: String?) -> String? {
    string?.replacingOccurrences(of: "\u{202F}", with: " ")
}

private let metric = DisplayUnits(fahrenheit: false, mph: false)
private let english = Locale(identifier: "en_US")

private let dewy = F.night { F.hour($0, temp: 12, dewPoint: 10, wind: 1) }
private let cloudyThenClear = F.night { d in F.hour(d, temp: 12, dewPoint: 10, cloud: d < F.at(1, 2) ? 0.8 : 0.1, wind: 1) }
private let cloudy = F.night { F.hour($0, temp: 12, dewPoint: 10, cloud: 0.8, wind: 1) }

struct SpreadMissTests {
    @Test func spreadMissNamesWhatWasMissing() {
        let hours = { (night: NightForecast) in NightWindow(night, packByMinutes: 8 * 60).nightHours }
        #expect(SpreadMiss.of(.dew, hours: hours(cloudy), settings: Settings()) == .cloudy)
        #expect(SpreadMiss.of(.dew, hours: hours(dewy), settings: Settings()) == nil)
        #expect(SpreadMiss.of(.frost, hours: hours(dewy), settings: Settings()) == .otherSideOfFrostLine)
        #expect(SpreadMiss.of(.dew, hours: hours(F.night()), settings: Settings()) == .tooDry(closestC: 10))
    }
}

struct MorningTextTests {
    /// The morning after a night whose call is sealed from `forecast`, when it came before the anchor.
    private func morning(call forecast: NightForecast, settings: Settings = Settings()) -> MorningText {
        MorningText(
            text: VerdictText(night: fetched(F.night(), at: F.at(1, 7)), settings: Settings(), units: metric, locale: english),
            call: NightCall.seal(forecast, settings: settings)
        )
    }

    @Test func theHeadlineIsWhatTheCallExpected() {
        let dew = morning(call: fetched(dewy, at: F.at(0, 21)))
        #expect(dew.headline == "Rainfly expected dew")
        #expect(dew.brief == "Expected dew")
        #expect(dew.flyOn)
        let likely = F.night { F.hour($0, temp: 12, dewPoint: 10, wind: 1, chance: 0.6) }
        #expect(morning(call: fetched(likely, at: F.at(0, 21))).headline == "Rainfly expected rain")
        let dry = morning(call: fetched(F.night(), at: F.at(0, 21)))
        #expect(dry.headline == "Rainfly expected a dry night")
        #expect(!dry.flyOn)
    }

    @Test func theCallGoesByTheSettingsItWasSealedWith() {
        var wide = Settings()
        wide.dewSpreadC = 5
        let nearly = fetched(F.night { F.hour($0, temp: 12, dewPoint: 8, wind: 1) }, at: F.at(0, 21))
        #expect(morning(call: nearly, settings: wide).headline == "Rainfly expected dew")
        #expect(morning(call: nearly).headline == "Rainfly expected a dry night")
    }

    @Test func coldAloneIsACallForAColdNight() {
        var cold = Settings()
        cold.coldC = 20
        let words = morning(call: fetched(F.night(), at: F.at(0, 21)), settings: cold)
        #expect(words.headline == "Rainfly expected a cold night")
        #expect(words.flyOn)
    }

    @Test func aNightWithNoForecastBeforeTheAnchorHasNoCall() {
        let words = morning(call: fetched(dewy, at: F.at(1, 0, 58)))
        #expect(words.headline == "Rainfly made no call last night")
        #expect(words.brief == "No call last night")
        #expect(!words.flyOn)
    }

    @Test func theMorningQuestionReadsAsTheCall() {
        #expect(MorningText.expected(Firing(trigger: .dew, at: F.at(0, 22))) == "Rainfly expected dew")
        #expect(MorningText.expected(Firing(trigger: .frost, at: F.at(1, 4))) == "Rainfly expected frost")
        #expect(MorningText.expected(Firing(trigger: .storm, at: F.at(1, 1))) == "Rainfly expected a storm")
        #expect(MorningText.expected(Firing(trigger: .windRain, at: F.at(1, 1))) == "Rainfly expected rain")
        #expect(MorningText.expected(nil) == "Rainfly expected a dry night")
        #expect(MorningText.expected(nil, afterRain: true) == "Rainfly expected no dew or frost")
    }

    @Test func tonightTakesOverAtNoon() {
        #expect(plain(morning(call: fetched(dewy, at: F.at(0, 21))).handoverTime) == "12 PM")
    }
}

struct OvernightTextTests {
    /// The night's call is sealed from `forecast`, when it came before the anchor.
    private func overnight(
        call forecast: NightForecast, latest: NightForecast, at now: Date? = nil, current: CurrentConditions? = nil
    ) -> OvernightText {
        OvernightText(
            text: VerdictText(night: latest, settings: Settings(), units: metric, locale: english),
            call: NightCall.seal(forecast, settings: Settings()), now: now ?? latest.fetchedAt, current: current
        )
    }

    @Test func the22CallKeepsItsOwnChanceOfRain() {
        let rainAt1 = { (chance: Double) in F.night { d in F.hour(d, chance: d == F.at(1, 1) ? chance : 0) } }
        let words = overnight(call: fetched(rainAt1(0.4), at: F.at(0, 21)), latest: fetched(F.night(), at: F.at(1, 0, 30)))
        #expect(plain(words.note) == "At 10 PM, Rainfly said on: rain 40% at 1 AM")
    }

    @Test func aChangeSince22IsNamed() {
        let rainLater = F.night { d in F.hour(d, temp: 12, dewPoint: 10, wind: 1, chance: d == F.at(1, 5) ? 0.4 : 0) }
        let words = overnight(call: fetched(dewy, at: F.at(0, 21)), latest: fetched(rainLater, at: F.at(1, 2)))
        #expect(words.hasChanged)
        #expect(plain(words.reason) == "New since 10 PM: rain 40% at 5 AM")
        #expect(plain(words.note) == "At 10 PM, Rainfly said on: dew likely by 10 PM")
        #expect(plain(words.inline) == "New: rain 5 AM")
    }

    @Test func aSingleForecastHasNothingToCompare() {
        let only = fetched(dewy, at: F.at(1, 1, 50))
        #expect(overnight(call: only, latest: only).note == nil)
    }

    @Test func noChangeSaysSo() {
        let words = overnight(call: fetched(dewy, at: F.at(0, 21)), latest: fetched(dewy, at: F.at(1, 2)), at: F.at(1, 2, 10))
        #expect(!words.hasChanged)
        #expect(plain(words.note) == "Same as the 10 PM forecast")
        #expect(words.hoursAhead.map(\.date) == [F.at(1, 2), F.at(1, 3), F.at(1, 4), F.at(1, 5)])
    }

    @Test func rainInAnHourAlreadyPastIsNotNew() {
        let rainedAt20 = F.night { d in F.hour(d, temp: 12, dewPoint: 10, wind: 1, amount: d == F.at(0, 20) ? 0.5 : 0) }
        let words = overnight(call: fetched(dewy, at: F.at(0, 21)), latest: fetched(rainedAt20, at: F.at(1, 2)))
        #expect(!words.hasChanged)
        #expect(words.headline == "Rainfly on")
        #expect(plain(words.reason) == "The rainfly is wet from rain at 8 PM")
        #expect(words.ahead.verdict.firing(.rain) == nil)
        #expect(plain(words.inline) == "Rainfly on · Dew 2 AM")
    }

    @Test func aWetRainflyStaysOnUntilItHasDried() {
        let rainAt23 = { (wind: Double) in F.night { d in F.hour(d, wind: wind, amount: d == F.at(0, 23) ? 1 : 0) } }
        let breezy = fetched(rainAt23(8), at: F.at(0, 21))
        let wet = overnight(call: breezy, latest: breezy, at: F.at(1, 2, 30))
        #expect(wet.headline == "Rainfly on")
        #expect(plain(wet.reason) == "The rainfly is wet from rain at 11 PM")
        let dried = overnight(call: breezy, latest: breezy, at: F.at(1, 4, 30))
        #expect(dried.headline == "Rainfly off")
        #expect(dried.reason == "Nothing more expected tonight")
        let still = fetched(rainAt23(1), at: F.at(0, 21))
        #expect(overnight(call: still, latest: still, at: F.at(1, 5)).headline == "Rainfly on")
    }

    @Test func rainRightNowWetsTheRainfly() {
        let dry = fetched(F.night(), at: F.at(0, 21))
        let raining = CurrentConditions(date: F.at(1, 3, 15), tempC: 15, dewPointC: 5, cloudCover: 0.9, windMS: 4, isRaining: true)
        let words = overnight(call: dry, latest: dry, at: F.at(1, 3, 20), current: raining)
        #expect(words.headline == "Rainfly on")
        #expect(plain(words.reason) == "The rainfly is wet from rain at 3:15 AM")
        #expect(overnight(call: dry, latest: dry, at: F.at(1, 3, 20)).headline == "Rainfly off")
    }

    @Test func rightNowNamesWhatIsHappening() {
        let words = overnight(call: dewy, latest: dewy)
        let forming = CurrentConditions(date: F.at(1, 2), tempC: 7, dewPointC: 5, cloudCover: 0.1, windMS: 1, isRaining: false)
        #expect(words.now(forming).title == "Dew is forming")
        let cloudyNow = CurrentConditions(date: F.at(1, 2), tempC: 7, dewPointC: 5, cloudCover: 0.9, windMS: 1, isRaining: false)
        #expect(words.now(cloudyNow).detail == "The air is 2.0° from its dew point, but the clouds keep the tent from cooling down.")
        let dryNow = CurrentConditions(date: F.at(1, 2), tempC: 15, dewPointC: 5, cloudCover: 0.1, windMS: 1, isRaining: false)
        #expect(words.now(dryNow).title == "Dry right now")
    }

    @Test func pressureTrendCoversItsHours() {
        var log = PressureLog()
        for (offset, hPa) in [(0.0, 1015.0), (3600.0, 1014.6), (7200.0, 1014.2), (10_800.0, 1014.0)] {
            log.record(PressureSample(date: F.at(0, 23).addingTimeInterval(offset), hPa: hPa))
        }
        let trend = log.trend(at: F.at(1, 2, 30))!
        #expect(log.trend(at: F.at(1, 4)) == nil)
        #expect(trend.trend == .falling)
        #expect(OvernightText.pressure(trend) == "Dropping slowly over the last 3 hours")
    }
}

@MainActor
struct OvernightAlertTests {
    private func message(call forecast: NightForecast, latest: NightForecast, at now: Date) -> (title: String, body: String)? {
        NightCall.seal(forecast, settings: Settings()).flatMap {
            OvernightAlert.message(night: latest, call: $0, settings: Settings(), units: metric, at: now)
        }
    }

    @Test func goesOutWhenTheForecastTurnsTheRainflyOnOvernight() {
        let alert = message(call: fetched(cloudy, at: F.at(0, 21)), latest: fetched(cloudyThenClear, at: F.at(1, 1)), at: F.at(1, 1))
        #expect(alert?.title == "Put the rainfly on")
        #expect(alert?.body.hasSuffix("Rainfly said it could stay off.") == true)
    }

    @Test func staysQuietOtherwise() {
        #expect(message(call: fetched(cloudy, at: F.at(0, 21)), latest: fetched(cloudyThenClear, at: F.at(0, 21)), at: F.at(0, 21)) == nil)
        #expect(message(call: fetched(dewy, at: F.at(0, 21)), latest: fetched(dewy, at: F.at(1, 1)), at: F.at(1, 1)) == nil)
        #expect(message(call: fetched(cloudy, at: F.at(0, 21)), latest: fetched(cloudy, at: F.at(1, 1)), at: F.at(1, 1)) == nil)
        let rainedAt20 = F.night { d in F.hour(d, temp: 12, dewPoint: 10, cloud: 0.8, wind: 1, amount: d == F.at(0, 20) ? 0.5 : 0) }
        #expect(message(call: fetched(cloudy, at: F.at(0, 21)), latest: fetched(rainedAt20, at: F.at(1, 1)), at: F.at(1, 1)) == nil)
    }
}
