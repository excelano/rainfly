// ComplicationTests.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
import Testing
@testable import Zeltwetter_Watch_App

private typealias F = Fixture

/// The faces use the device's locale, so exact times are checked in VerdictTextTests.
private func plain(_ string: String) -> String {
    string.lowercased()
}

struct ComplicationTimelineTests {
    /// The night's call is sealed from `called`, or from the night itself, as fetched at 18:00.
    private func entries(_ night: NightForecast, now: Date, next: NightForecast? = nil, called: NightForecast? = nil) -> [(date: Date, face: ComplicationFace)] {
        ComplicationTimeline.entries(now: now, settings: Settings(), units: .locale) { date in
            (date < F.at(1, 12) ? night : next).map { NightFetches(latest: $0, call: NightCall.seal(called ?? $0, settings: Settings())) }
        }
    }

    @Test func noCachedNightShowsNoForecast() {
        let timeline = ComplicationTimeline.entries(now: F.at(0, 18), settings: Settings(), units: .locale) { _ in nil }
        #expect(timeline.count == 1)
        #expect(timeline[0].face == .noForecast)
    }

    @Test func entriesMarkTheNightsChangesUntilNoon() {
        let night = F.night { d in F.hour(d, chance: d == F.at(1, 2) ? 0.5 : 0) }
        let dates = entries(night, now: F.at(0, 18, 20)).map(\.date)
        #expect(dates == dates.sorted())
        #expect(Set(dates).count == dates.count)
        #expect(dates.first == F.at(0, 18, 20))
        #expect(dates.last == F.at(1, 12))
        for mark in [F.sunset, F.at(0, 22), F.at(1, 2), F.sunrise, F.at(0, 19), F.at(1, 7)] {
            #expect(dates.contains(mark))
        }
    }

    @Test func nothingBeforeNow() {
        let timeline = entries(F.night(), now: F.at(1, 2, 30))
        #expect(timeline.first?.date == F.at(1, 2, 30))
        #expect(!timeline.map(\.date).contains(F.sunset))
    }

    @Test func verdictUntilSunriseThenTheCall() {
        let timeline = entries(F.dewyNight { F.hour($0, temp: 15, dewPoint: 5) }, now: F.at(0, 21))
        let night = timeline.first { $0.date == F.at(1, 5) }!.face
        #expect(night.flyOn == true)
        #expect(plain(night.inline) == "rainfly on · wet")

        let morning = timeline.first { $0.date == F.sunrise }!.face
        #expect(morning.flyOn == true)
        #expect(morning.headline == "Expected dew")
        #expect(morning.detail == "Last night")
        #expect(morning.inline == "Rainfly expected dew")
    }

    @Test func theMorningTentIsTheCallsNotTheLatestForecasts() {
        let dewy = F.dewyNight { F.hour($0, temp: 15, dewPoint: 5) }
        let afterADryCall = entries(dewy, now: F.sunrise, called: F.night())[0].face
        #expect(afterADryCall.flyOn == false)
        #expect(afterADryCall.headline == "Expected a dry night")

        let afterADewyCall = entries(F.night(), now: F.sunrise, called: dewy)[0].face
        #expect(afterADewyCall.flyOn == true)
        #expect(afterADewyCall.headline == "Expected dew")
    }

    @Test func aMorningWithNoCallSaysSo() {
        let late = F.night()
        let unsealed = NightForecast(location: late.location, fetchedAt: F.at(1, 1), sunset: late.sunset, sunrise: late.sunrise, hours: late.hours)
        let morning = entries(unsealed, now: F.at(1, 7))[0].face
        #expect(morning.flyOn == nil)
        #expect(morning.headline == "No call last night")
    }

    @Test func overnightFacesNameAChangeSince22() {
        let dewy = F.night { F.hour($0, temp: 12, dewPoint: 10, wind: 1) }
        let rainLater = F.night { d in F.hour(d, temp: 12, dewPoint: 10, wind: 1, chance: d == F.at(1, 5) ? 0.4 : 0) }
        let face = entries(rainLater, now: F.at(1, 2), called: dewy)[0].face
        #expect(face.headline == "Rainfly on")
        #expect(plain(face.inline).hasPrefix("new: rain "))
    }

    @Test func clearNightFaces() {
        let face = entries(F.night(), now: F.at(0, 21))[0].face
        #expect(face.flyOn == false)
        #expect(face.headline == "Rainfly off tonight")
        #expect(face.inline == "Rainfly off tonight")
        #expect(face.detail == "Clear, dry, mild.")
        #expect(face.fetchedAt == F.at(0, 18))
    }

    @Test func noonHandsOverToTheNextNight() {
        let day: TimeInterval = 86_400
        let tonight = F.night { F.hour($0.addingTimeInterval(day), chance: 0.5) }
        let rainy = NightForecast(
            location: tonight.location, fetchedAt: tonight.fetchedAt.addingTimeInterval(day),
            sunset: tonight.sunset.addingTimeInterval(day), sunrise: tonight.sunrise.addingTimeInterval(day), hours: tonight.hours
        )
        #expect(entries(F.night(), now: F.at(0, 21)).last?.face == .noForecast)
        #expect(entries(F.night(), now: F.at(0, 21), next: rainy).last?.face.flyOn == true)
    }
}
