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

struct NightReviewTests {
    @Test func aRightForecastIsRightOnEveryCheck() {
        let review = NightReview(decided: fetched(dewy, at: F.at(0, 21)), record: fetched(dewy, at: F.at(1, 8)), settings: Settings())
        #expect(review.checks.map(\.trigger) == [.rain, .dew])
        #expect(review.checks.filter { !$0.isRight }.isEmpty)
    }

    @Test func aMissedDewNightIsWrong() {
        let review = NightReview(decided: fetched(cloudy, at: F.at(0, 21)), record: fetched(cloudyThenClear, at: F.at(1, 8)), settings: Settings())
        let dew = review.checks.first { $0.trigger == .dew }
        #expect(dew?.expected == nil)
        #expect(dew?.happened?.at == F.at(1, 2))
        #expect(dew?.isRight == false)
    }

    @Test func rainInTheRecordCountsOnlyWhereItFell() {
        let likely = F.night { F.hour($0, chance: 0.6) }
        let review = NightReview(decided: fetched(likely, at: F.at(0, 21)), record: fetched(likely, at: F.at(1, 8)), settings: Settings())
        let rain = review.checks.first { $0.trigger == .rain }
        #expect(rain?.expected != nil)
        #expect(rain?.happened == nil)
        #expect(rain?.isRight == false)
    }

    @Test func theRecordIsReadyTwoHoursAfterSunrise() {
        #expect(!NightReview.isRecord(fetched(dewy, at: F.at(1, 7))))
        #expect(NightReview.isRecord(fetched(dewy, at: F.at(1, 8))))
    }

    @Test func spreadMissNamesWhatWasMissing() {
        let hours = { (night: NightForecast) in NightWindow(night, packByMinutes: 8 * 60).nightHours }
        #expect(SpreadMiss.of(.dew, hours: hours(cloudy), settings: Settings()) == .cloudy)
        #expect(SpreadMiss.of(.dew, hours: hours(dewy), settings: Settings()) == nil)
        #expect(SpreadMiss.of(.frost, hours: hours(dewy), settings: Settings()) == .otherSideOfFrostLine)
        #expect(SpreadMiss.of(.dew, hours: hours(F.night()), settings: Settings()) == .tooDry(closestC: 10))
    }
}

struct MorningTextTests {
    private func morning(
        decided: NightForecast, beforeMorning: NightForecast? = nil, latest: NightForecast, alerted: Bool = false,
        settings: Settings = Settings(), decidedSettings: Settings = Settings()
    ) -> MorningText {
        MorningText(
            decided: decided, beforeMorning: beforeMorning, latest: latest, settings: settings, decidedSettings: decidedSettings,
            units: metric, alerted: alerted, locale: english
        )
    }

    @Test func lastNightIsTheCallMadeWithThatNightsSettings() {
        var wider = Settings()
        wider.dewSpreadC = 5
        let nearly = F.night { F.hour($0, temp: 12, dewPoint: 8, wind: 1) }
        let words = morning(decided: fetched(nearly, at: F.at(0, 21)), latest: fetched(nearly, at: F.at(1, 8)), settings: wider)
        #expect(plain(words.lastNightTitle) == "At 10 PM, Rainfly said off")
    }

    @Test func rainAfterSunriseWetsTheTentOnceItHasFallen() {
        let morningRain = F.night { d in F.hour(d, amount: d == F.at(1, 6) ? 0.5 : 0) }
        let fallen = morning(decided: fetched(F.night(), at: F.at(0, 21)), latest: fetched(morningRain, at: F.at(1, 7, 30)))
        #expect(fallen.headline == "Packing wet")
        #expect(fallen.reason == "It rained this morning, so the rainfly is wet")
        let coming = morning(decided: fetched(F.night(), at: F.at(0, 21)), latest: fetched(morningRain, at: F.at(1, 5, 50)))
        #expect(coming.headline == "Dry night")
    }

    @Test func aFirstForecastAfterSunriseMadeNoCall() {
        #expect(!morning(decided: fetched(dewy, at: F.at(1, 7)), latest: fetched(dewy, at: F.at(1, 7))).madeACall)
        #expect(morning(decided: fetched(dewy, at: F.at(1, 2)), latest: fetched(dewy, at: F.at(1, 7))).madeACall)
    }

    @Test func aRightNightReadsRight() {
        let words = morning(decided: fetched(dewy, at: F.at(0, 21)), latest: fetched(dewy, at: F.at(1, 8)))
        #expect(plain(words.lastNightTitle) == "At 10 PM, Rainfly said on")
        #expect(plain(words.lastNightDetail) == "Because of dew from 8 PM.")
        #expect(plain(words.reviewTitle) == "Was the 10 PM forecast right?")
        let dew = words.review!.checks.first { $0.trigger == .dew }!
        #expect(plain(words.explain(dew)) == "Apple Weather's record shows the air got within 2.0° of its dew point at 8 PM, with a clear sky and little wind.")
        let rain = words.review!.checks.first { $0.trigger == .rain }!
        #expect(plain(words.explain(rain)) == "At 10 PM the chance was 0%. No rain fell.")
    }

    @Test func aWrongNightSaysWhatHappened() {
        let words = morning(
            decided: fetched(cloudy, at: F.at(0, 21)), beforeMorning: fetched(cloudyThenClear, at: F.at(1, 1)),
            latest: fetched(cloudyThenClear, at: F.at(1, 8)), alerted: true
        )
        #expect(plain(words.lastNightTitle) == "At 10 PM, Rainfly said off")
        #expect(plain(words.lastNightDetail) == "By 1 AM the forecast changed to on because of dew, and Rainfly sent you an alert.")
        let dew = words.review!.checks.first { $0.trigger == .dew }!
        #expect(plain(words.explain(dew)) == "At 10 PM Rainfly expected clouds all night, so no dew. Apple Weather's record shows the air got within 2.0° of its dew point at 2 AM, with a clear sky and little wind.")
    }

    @Test func anHourPastAt22IsNotAChangeOvernight() {
        let rainedAt20 = F.night { d in F.hour(d, temp: 12, dewPoint: 10, cloud: 0.8, wind: 1, amount: d == F.at(0, 20) ? 0.5 : 0) }
        let words = morning(
            decided: fetched(cloudy, at: F.at(0, 21)), beforeMorning: fetched(rainedAt20, at: F.at(1, 5)),
            latest: fetched(rainedAt20, at: F.at(1, 8))
        )
        #expect(plain(words.lastNightDetail) == "It expected a clear, dry night.")
    }

    @Test func theReviewWaitsForTheRecord() {
        let words = morning(decided: fetched(dewy, at: F.at(0, 21)), latest: fetched(dewy, at: F.at(1, 6)))
        #expect(words.review == nil)
        #expect(plain(words.reviewPending) == "Apple Weather's record of last night will be ready around 7:45 AM.")
    }

    @Test func packingComparesDryingWithPackingUp() {
        let dries = F.dewyNight { F.hour($0, temp: 15, dewPoint: 5) }
        let dryToPack = morning(decided: dries, latest: dries)
        #expect(dryToPack.headline == "Dry to pack")
        #expect(plain(dryToPack.reason) == "It should be dry around 6:45 AM, before you pack up at 8 AM")
        #expect(dryToPack.advice == nil)

        let staysWet = F.dewyNight { F.hour($0, temp: 10, dewPoint: 9.5, cloud: 1, wind: 0) }
        let wet = morning(decided: staysWet, latest: staysWet)
        #expect(wet.headline == "Packing wet")
        #expect(wet.reason == "It won't be dry before noon")
        #expect(wet.advice != nil)

        let dry = morning(decided: F.night(), latest: F.night())
        #expect(dry.headline == "Dry night")
    }

    @Test func durationsReadAsWords() {
        #expect(MorningText.duration(1800) == "half an hour")
        #expect(MorningText.duration(3600) == "an hour")
        #expect(MorningText.duration(5400) == "an hour and a half")
        #expect(MorningText.duration(7200) == "two hours")
        #expect(MorningText.duration(9000) == "two and a half hours")
    }
}

struct OvernightTextTests {
    private func overnight(
        decided: NightForecast, latest: NightForecast, at now: Date? = nil, current: CurrentConditions? = nil
    ) -> OvernightText {
        OvernightText(
            text: VerdictText(night: latest, verdict: FlyEngine.evaluate(latest, settings: Settings()), settings: Settings(), units: metric, locale: english),
            decided: decided, decidedSettings: Settings(), now: now ?? latest.fetchedAt, current: current
        )
    }

    @Test func the22CallKeepsItsOwnChanceOfRain() {
        let rainAt1 = { (chance: Double) in F.night { d in F.hour(d, chance: d == F.at(1, 1) ? chance : 0) } }
        let words = overnight(decided: fetched(rainAt1(0.4), at: F.at(0, 21)), latest: fetched(F.night(), at: F.at(1, 0, 30)))
        #expect(plain(words.note) == "At 10 PM, Rainfly said on: rain 40% at 1 AM")
    }

    @Test func aChangeSince22IsNamed() {
        let rainLater = F.night { d in F.hour(d, temp: 12, dewPoint: 10, wind: 1, chance: d == F.at(1, 5) ? 0.4 : 0) }
        let words = overnight(decided: fetched(dewy, at: F.at(0, 21)), latest: fetched(rainLater, at: F.at(1, 2)))
        #expect(words.hasChanged)
        #expect(plain(words.reason) == "New since 10 PM: rain 40% at 5 AM")
        #expect(plain(words.note) == "At 10 PM, Rainfly said on: dew likely by 8 PM")
        #expect(plain(words.inline) == "New: rain 5 AM")
    }

    @Test func aSingleForecastHasNothingToCompare() {
        let only = fetched(dewy, at: F.at(1, 1, 50))
        #expect(overnight(decided: only, latest: only).note == nil)
    }

    @Test func noChangeSaysSo() {
        let words = overnight(decided: fetched(dewy, at: F.at(0, 21)), latest: fetched(dewy, at: F.at(1, 2)), at: F.at(1, 2, 10))
        #expect(!words.hasChanged)
        #expect(plain(words.note) == "Same as the 10 PM forecast")
        #expect(words.hoursAhead.map(\.date) == [F.at(1, 2), F.at(1, 3), F.at(1, 4), F.at(1, 5)])
    }

    @Test func rainInAnHourAlreadyPastIsNotNew() {
        let rainedAt20 = F.night { d in F.hour(d, temp: 12, dewPoint: 10, wind: 1, amount: d == F.at(0, 20) ? 0.5 : 0) }
        let words = overnight(decided: fetched(dewy, at: F.at(0, 21)), latest: fetched(rainedAt20, at: F.at(1, 2)))
        #expect(!words.hasChanged)
        #expect(words.headline == "Rainfly on")
        #expect(plain(words.reason) == "The rainfly is wet from rain at 8 PM")
        #expect(words.ahead.verdict.firing(.rain) == nil)
        #expect(plain(words.inline) == "Rainfly on · Dew 2 AM")
    }

    @Test func aWetRainflyStaysOnUntilItHasDried() {
        let rainAt23 = { (wind: Double) in F.night { d in F.hour(d, wind: wind, amount: d == F.at(0, 23) ? 1 : 0) } }
        let breezy = fetched(rainAt23(4), at: F.at(0, 21))
        let wet = overnight(decided: breezy, latest: breezy, at: F.at(1, 0, 30))
        #expect(wet.headline == "Rainfly on")
        #expect(plain(wet.reason) == "The rainfly is wet from rain at 11 PM")
        let dried = overnight(decided: breezy, latest: breezy, at: F.at(1, 2, 30))
        #expect(dried.headline == "Rainfly off")
        #expect(dried.reason == "Nothing more expected tonight")
        let still = fetched(rainAt23(1), at: F.at(0, 21))
        #expect(overnight(decided: still, latest: still, at: F.at(1, 5)).headline == "Rainfly on")
    }

    @Test func rainRightNowWetsTheRainfly() {
        let dry = fetched(F.night(), at: F.at(0, 21))
        let raining = CurrentConditions(date: F.at(1, 3, 15), tempC: 15, dewPointC: 5, cloudCover: 0.9, windMS: 4, isRaining: true)
        let words = overnight(decided: dry, latest: dry, at: F.at(1, 3, 20), current: raining)
        #expect(words.headline == "Rainfly on")
        #expect(plain(words.reason) == "The rainfly is wet from rain at 3:15 AM")
        #expect(overnight(decided: dry, latest: dry, at: F.at(1, 3, 20)).headline == "Rainfly off")
    }

    @Test func rightNowNamesWhatIsHappening() {
        let words = overnight(decided: dewy, latest: dewy)
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
    private func message(decided: NightForecast, latest: NightForecast, at now: Date) -> (title: String, body: String)? {
        OvernightAlert.message(
            night: latest, decided: decided, decidedSettings: Settings(), settings: Settings(), units: metric, at: now
        )
    }

    @Test func goesOutWhenTheForecastTurnsTheRainflyOnOvernight() {
        let alert = message(decided: fetched(cloudy, at: F.at(0, 21)), latest: fetched(cloudyThenClear, at: F.at(1, 1)), at: F.at(1, 1))
        #expect(alert?.title == "Put the rainfly on")
        #expect(alert?.body.hasSuffix("Rainfly said it could stay off.") == true)
    }

    @Test func staysQuietOtherwise() {
        #expect(message(decided: fetched(cloudy, at: F.at(0, 21)), latest: fetched(cloudyThenClear, at: F.at(0, 21)), at: F.at(0, 21)) == nil)
        #expect(message(decided: fetched(dewy, at: F.at(0, 21)), latest: fetched(dewy, at: F.at(1, 1)), at: F.at(1, 1)) == nil)
        #expect(message(decided: fetched(cloudy, at: F.at(0, 21)), latest: fetched(cloudy, at: F.at(1, 1)), at: F.at(1, 1)) == nil)
        let rainedAt20 = F.night { d in F.hour(d, temp: 12, dewPoint: 10, cloud: 0.8, wind: 1, amount: d == F.at(0, 20) ? 0.5 : 0) }
        #expect(message(decided: fetched(cloudy, at: F.at(0, 21)), latest: fetched(rainedAt20, at: F.at(1, 1)), at: F.at(1, 1)) == nil)
    }
}
