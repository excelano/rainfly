// FlyEngineTests.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
import Testing
@testable import Zeltwetter_Watch_App

private typealias F = Fixture

private func evaluate(_ night: NightForecast, _ settings: Settings = Settings()) -> Verdict {
    FlyEngine.evaluate(night, settings: settings)
}

private func triggers(_ verdict: Verdict) -> [Trigger] {
    verdict.firings.map(\.trigger)
}

struct FlyEngineTests {
    @Test func clearDryMildBreezyNightIsFlyOff() {
        let verdict = evaluate(F.night())
        #expect(!verdict.flyOn)
        #expect(verdict.firings.isEmpty)
        #expect(!verdict.ventAdvice)
        #expect(verdict.bagWarning == nil)
        #expect(verdict.dryBy == nil)
    }

    @Test func oneHourAtTwentyPercentFiresRainThere() {
        let verdict = evaluate(F.night { d in F.hour(d, chance: d == F.at(1, 2) ? 0.20 : 0) })
        #expect(verdict.flyOn)
        #expect(verdict.firings == [Firing(trigger: .rain, at: F.at(1, 2))])

        let below = evaluate(F.night { d in F.hour(d, chance: d == F.at(1, 2) ? 0.19 : 0) })
        #expect(!below.flyOn)
    }

    @Test func measurablePrecipitationFiresRainAtAnyChance() {
        let verdict = evaluate(F.night { d in F.hour(d, chance: 0.05, amount: d == F.at(0, 23) ? 0.1 : 0) })
        #expect(verdict.firings == [Firing(trigger: .rain, at: F.at(0, 23))])
    }

    @Test func thunderstormAtFivePercentFiresStorm() {
        let verdict = evaluate(F.night { d in
            d == F.at(0, 23) ? F.hour(d, chance: 0.05, storm: true) : F.hour(d)
        })
        #expect(verdict.firings == [Firing(trigger: .storm, at: F.at(0, 23))])
    }

    @Test func stormBeforePackByCounts() {
        let verdict = evaluate(F.night { d in F.hour(d, storm: d == F.at(1, 7)) })
        #expect(verdict.firings == [Firing(trigger: .storm, at: F.at(1, 7))])
    }

    @Test func dewNeedsSmallSpreadClearSkyAndCalm() {
        let dew = evaluate(F.night { F.hour($0, temp: 12, dewPoint: 10, cloud: 0.1, wind: 1) })
        #expect(triggers(dew) == [.dew])
        #expect(dew.firing(.dew)?.at == F.at(0, 20))

        let cloudy = evaluate(F.night { F.hour($0, temp: 12, dewPoint: 10, cloud: 0.4, wind: 1) })
        #expect(cloudy.firing(.dew) == nil)

        let windy = evaluate(F.night { F.hour($0, temp: 12, dewPoint: 10, cloud: 0.1, wind: 4) })
        #expect(windy.firing(.dew) == nil)
    }

    @Test func belowFreezingIsFrostNotDew() {
        let verdict = evaluate(F.night { F.hour($0, temp: -1, dewPoint: -3, cloud: 0.1, wind: 1) })
        #expect(verdict.firing(.frost)?.at == F.at(0, 20))
        #expect(verdict.firing(.dew) == nil)
    }

    @Test func nineDegreeLowIsColdOnly() {
        let verdict = evaluate(F.night { d in F.hour(d, temp: d == F.at(1, 4) ? 9 : 14, dewPoint: 0) })
        #expect(verdict.firings == [Firing(trigger: .cold, at: F.at(1, 4))])
    }

    @Test func rainBetweenSunriseAndPackByIsMorningRain() {
        let verdict = evaluate(F.night { d in F.hour(d, chance: d >= F.at(1, 6) && d <= F.at(1, 7) ? 0.5 : 0) })
        #expect(verdict.firings == [Firing(trigger: .morningRain, at: F.at(1, 6))])
    }

    @Test func rainAfterPackByIsIgnored() {
        let verdict = evaluate(F.night { d in F.hour(d, chance: d >= F.at(1, 8) ? 0.9 : 0) })
        #expect(!verdict.flyOn)
    }

    @Test func hourHoldingSunriseCountsForTheNightAndTheMorning() {
        let verdict = evaluate(F.night { d in F.hour(d, chance: d == F.at(1, 5) ? 0.5 : 0) })
        #expect(verdict.firings == [Firing(trigger: .rain, at: F.at(1, 5)), Firing(trigger: .morningRain, at: F.at(1, 5))])

        var settings = Settings()
        settings.packByMinutes = 6 * 60
        let lightRain = F.night { d in F.hour(d, chance: d == F.at(1, 5) ? 0.1 : 0) }
        settings.morningRainChance = 0.1
        #expect(triggers(evaluate(lightRain, settings)) == [.morningRain])
    }

    @Test func hourHoldingSunsetBelongsToTheNight() {
        let verdict = evaluate(F.night { d in F.hour(d, chance: d == F.at(0, 19) ? 0.5 : 0) })
        #expect(!verdict.flyOn)

        let sunsetHour = evaluate(F.night { d in F.hour(d, chance: d == F.at(0, 20) ? 0.5 : 0) })
        #expect(sunsetHour.firings == [Firing(trigger: .rain, at: F.at(0, 20))])
    }

    @Test func gustsWithAnyRainChanceFireWindRain() {
        let verdict = evaluate(F.night { d in
            d == F.at(1, 1) ? F.hour(d, wind: 5, gust: 10, chance: 0.05) : F.hour(d)
        })
        #expect(verdict.firings == [Firing(trigger: .windRain, at: F.at(1, 1))])

        let atThreshold = evaluate(F.night { d in
            d == F.at(1, 1) ? F.hour(d, wind: 5, gust: 8, chance: 0.05) : F.hour(d)
        })
        #expect(!atThreshold.flyOn)

        let dryGale = evaluate(F.night { d in F.hour(d, wind: 12, gust: 20) })
        #expect(!dryGale.flyOn)
    }

    @Test func headlineFollowsPriority() {
        #expect(Trigger.allCases == [.storm, .rain, .windRain, .frost, .dew, .morningRain, .cold])

        let verdict = evaluate(F.night { d in
            switch d {
            case F.at(0, 22): F.hour(d, temp: 8, dewPoint: 6, wind: 1, chance: 0.3)
            case F.at(1, 3): F.hour(d, temp: 8, dewPoint: 6, wind: 1, chance: 0.3, storm: true)
            case F.at(1, 6): F.hour(d, chance: 0.5)
            default: F.hour(d, temp: 8, dewPoint: 6, wind: 1)
            }
        })
        #expect(triggers(verdict) == [.storm, .rain, .dew, .morningRain, .cold])
        #expect(verdict.headline == Firing(trigger: .storm, at: F.at(1, 3)))
    }

    @Test func eachTriggerRecordsItsEarliestHour() {
        let rainy: Set = [F.at(0, 22), F.at(1, 1), F.at(1, 3)]
        let night = F.night { d in F.hour(d, temp: d == F.at(1, 2) ? 9 : 14, chance: rainy.contains(d) ? 0.6 : 0) }
        let shuffled = NightForecast(
            location: night.location, fetchedAt: night.fetchedAt, sunset: night.sunset, sunrise: night.sunrise,
            hours: night.hours.reversed()
        )
        let verdict = evaluate(shuffled)
        #expect(verdict.firings == [
            Firing(trigger: .rain, at: F.at(0, 22)),
            Firing(trigger: .cold, at: F.at(1, 2)),
        ])
    }

    @Test func ventAdvice() {
        let humidRain = evaluate(F.night { d in F.hour(d, humidity: d == F.at(1, 4) ? 0.85 : 0.5, chance: 0.5) })
        #expect(humidRain.ventAdvice)

        let calmRain = evaluate(F.night { d in F.hour(d, wind: d == F.at(1, 4) ? 2 : 4, chance: 0.5) })
        #expect(calmRain.ventAdvice)

        let breezyDryRain = evaluate(F.night { F.hour($0, chance: 0.5) })
        #expect(breezyDryRain.flyOn)
        #expect(!breezyDryRain.ventAdvice)

        let humidButFlyOff = evaluate(F.night { F.hour($0, humidity: 0.95) })
        #expect(!humidButFlyOff.flyOn)
        #expect(!humidButFlyOff.ventAdvice)
    }

    @Test func bagWarningComparesTheNightLow() {
        let night = F.night { d in
            switch d {
            case F.at(1, 4): F.hour(d, temp: 9, dewPoint: 0)
            case F.at(1, 7): F.hour(d, temp: 2, dewPoint: -5)
            default: F.hour(d)
            }
        }
        var settings = Settings()
        #expect(evaluate(night, settings).bagWarning == nil)

        settings.bagRatingC = 12
        #expect(evaluate(night, settings).bagWarning == BagWarning(lowC: 9, ratingC: 12))

        settings.bagRatingC = 9
        #expect(evaluate(night, settings).bagWarning == nil)
    }

    @Test func dewDriesAnHourAfterASunnyDrySunrise() {
        let verdict = evaluate(F.dewyNight { F.hour($0, temp: 15, dewPoint: 5) })
        #expect(verdict.firing(.dew) != nil)
        #expect(verdict.dryBy == F.at(1, 6, 45))
    }

    @Test func dewWaitsForTheFirstDryingHour() {
        let verdict = evaluate(F.dewyNight { d in
            d < F.at(1, 8) ? F.hour(d, temp: 9, dewPoint: 8, cloud: 0.9, wind: 1) : F.hour(d, temp: 16, dewPoint: 6)
        })
        #expect(verdict.dryBy == F.at(1, 9))
    }

    @Test func breezeDriesUnderCloud() {
        let verdict = evaluate(F.dewyNight { F.hour($0, temp: 15, dewPoint: 5, cloud: 0.9, wind: 2) })
        #expect(verdict.dryBy == F.at(1, 6, 45))
    }

    @Test func frostAddsHalfAnHour() {
        let verdict = evaluate(F.dewyNight(temp: -1) { F.hour($0, temp: 8, dewPoint: -2) })
        #expect(verdict.firing(.frost) != nil)
        #expect(verdict.dryBy == F.at(1, 7, 15))
    }

    @Test func persistentFogNeverDries() {
        let verdict = evaluate(F.dewyNight { F.hour($0, temp: 10, dewPoint: 9.5, humidity: 1, cloud: 1, wind: 0) })
        #expect(verdict.firing(.dew) != nil)
        #expect(verdict.dryBy == nil)
    }

    @Test func dryingThatStartsAtNoonIsTooLate() {
        let verdict = evaluate(F.dewyNight { d in
            d < F.at(1, 12) ? F.hour(d, temp: 10, dewPoint: 9.5, cloud: 1, wind: 0) : F.hour(d, temp: 18, dewPoint: 5)
        })
        #expect(verdict.dryBy == nil)
    }

    @Test func noDewMeansNoDryBy() {
        let verdict = evaluate(F.night { F.hour($0, chance: 0.5) })
        #expect(verdict.flyOn)
        #expect(verdict.dryBy == nil)
    }

    @Test func thresholdSettingsChangeTheOutcome() {
        let night = F.night { d in F.hour(d, temp: 9.5, dewPoint: 0, chance: d == F.at(1, 2) ? 0.3 : 0) }
        #expect(triggers(evaluate(night)) == [.rain, .cold])

        var settings = Settings()
        settings.rainChance = 0.4
        settings.coldC = 9
        #expect(!evaluate(night, settings).flyOn)

        settings.packByMinutes = 9 * 60
        let lateRain = F.night { d in F.hour(d, chance: d == F.at(1, 8) ? 0.5 : 0) }
        #expect(triggers(evaluate(lateRain, settings)) == [.morningRain])
    }

    @Test func forecastAndVerdictSurviveCodable() throws {
        let night = F.night { d in F.hour(d, gust: d == F.at(1, 1) ? 11 : nil, chance: 0.3, storm: d == F.at(1, 2)) }
        let decodedNight = try JSONDecoder().decode(NightForecast.self, from: JSONEncoder().encode(night))
        #expect(decodedNight == night)

        var settings = Settings()
        settings.bagRatingC = 20
        let verdict = evaluate(F.dewyNight { F.hour($0, temp: 15, dewPoint: 5) }, settings)
        #expect(verdict.bagWarning != nil)
        #expect(verdict.dryBy != nil)
        let decodedVerdict = try JSONDecoder().decode(Verdict.self, from: JSONEncoder().encode(verdict))
        #expect(decodedVerdict == verdict)
    }
}
