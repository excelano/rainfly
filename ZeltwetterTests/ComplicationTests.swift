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
    private func entries(_ night: NightForecast, now: Date, next: NightForecast? = nil, decided: NightForecast? = nil) -> [(date: Date, face: ComplicationFace)] {
        ComplicationTimeline.entries(now: now, settings: Settings(), units: .locale) { date in
            (date < F.at(1, 12) ? night : next).map { NightFetches(latest: $0, decided: decided) }
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
        for mark in [F.sunset, F.at(0, 22), F.at(1, 2), F.sunrise, F.at(1, 7, 45), F.at(0, 19), F.at(1, 7)] {
            #expect(dates.contains(mark))
        }
    }

    @Test func nothingBeforeNow() {
        let timeline = entries(F.night(), now: F.at(1, 2, 30))
        #expect(timeline.first?.date == F.at(1, 2, 30))
        #expect(!timeline.map(\.date).contains(F.sunset))
    }

    @Test func verdictUntilSunriseThenPacking() {
        let timeline = entries(F.dewyNight { F.hour($0, temp: 15, dewPoint: 5) }, now: F.at(0, 21))
        let night = timeline.first { $0.date == F.at(1, 5) }!.face
        #expect(night.flyOn == true)
        #expect(plain(night.inline) == "rainfly on · wet")
        #expect(night.dryTime == nil)

        let morning = timeline.first { $0.date == F.sunrise }!.face
        let text = VerdictText(night: F.night(), verdict: FlyEngine.evaluate(F.night(), settings: Settings()), settings: Settings(), units: .locale)
        let dryBy = text.compactClock(F.at(1, 6, 30))
        #expect(morning.headline == "Dry to pack")
        #expect(morning.dryTime == dryBy)
        #expect(morning.inline == "Dry to pack · dry \(dryBy)")
    }

    @Test func wetMorningWithoutDryByPacksWet() {
        let timeline = entries(F.dewyNight { F.hour($0, temp: 10, dewPoint: 9.5, cloud: 1, wind: 0) }, now: F.at(0, 21))
        let morning = timeline.first { $0.date == F.sunrise }!.face
        #expect(morning.dryTime == nil)
        #expect(morning.headline == "Packing wet")
        #expect(morning.detail == "It won't be dry before noon")
    }

    @Test func overnightFacesNameAChangeSince22() {
        let dewy = F.night { F.hour($0, temp: 12, dewPoint: 10, wind: 1) }
        let rainLater = F.night { d in F.hour(d, temp: 12, dewPoint: 10, wind: 1, chance: d == F.at(1, 5) ? 0.4 : 0) }
        let face = entries(rainLater, now: F.at(1, 2), decided: dewy)[0].face
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
