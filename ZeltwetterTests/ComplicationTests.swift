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
    private func entries(_ night: NightForecast, now: Date, next: NightForecast? = nil) -> [(date: Date, face: ComplicationFace)] {
        ComplicationTimeline.entries(now: now, settings: Settings(), units: .locale) { date in
            date < F.at(1, 8) ? night : next
        }
    }

    @Test func noCachedNightShowsNoForecast() {
        let timeline = ComplicationTimeline.entries(now: F.at(0, 18), settings: Settings(), units: .locale) { _ in nil }
        #expect(timeline.count == 1)
        #expect(timeline[0].face == .noForecast)
    }

    @Test func entriesMarkSunsetTriggersSunriseAndPackBy() {
        let night = F.night { d in F.hour(d, chance: d == F.at(1, 2) ? 0.5 : 0) }
        let dates = entries(night, now: F.at(0, 18, 20)).map(\.date)
        #expect(dates == dates.sorted())
        #expect(Set(dates).count == dates.count)
        #expect(dates.first == F.at(0, 18, 20))
        #expect(dates.last == F.at(1, 8))
        for mark in [F.sunset, F.at(1, 2), F.sunrise, F.at(0, 19), F.at(1, 7)] {
            #expect(dates.contains(mark))
        }
    }

    @Test func nothingBeforeNow() {
        let timeline = entries(F.night(), now: F.at(1, 2, 30))
        #expect(timeline.first?.date == F.at(1, 2, 30))
        #expect(!timeline.map(\.date).contains(F.sunset))
    }

    @Test func verdictUntilSunriseThenDryBy() {
        let timeline = entries(F.dewyNight { F.hour($0, temp: 15, dewPoint: 5) }, now: F.at(0, 21))
        let night = timeline.first { $0.date == F.at(1, 5) }!.face
        #expect(night.flyOn == true)
        #expect(plain(night.inline).hasPrefix("fly on · dew "))
        #expect(night.dryTime == nil)

        let morning = timeline.first { $0.date == F.sunrise }!.face
        let dryBy = F.at(1, 6, 45)
        let text = VerdictText(night: F.night(), verdict: FlyEngine.evaluate(F.night(), settings: Settings()), settings: Settings(), units: .locale)
        #expect(morning.dryTime == text.compactClock(dryBy))
        #expect(morning.inline == "Dry by \(text.compactClock(dryBy))")
        #expect(morning.detail == "Dry by ~\(text.clock(dryBy))")
    }

    @Test func wetMorningWithoutDryByKeepsTheVerdict() {
        let timeline = entries(F.dewyNight { F.hour($0, temp: 10, dewPoint: 9.5, cloud: 1, wind: 0) }, now: F.at(0, 21))
        let morning = timeline.first { $0.date == F.sunrise }!.face
        #expect(morning.dryTime == nil)
        #expect(morning.headline == "Fly on")
    }

    @Test func clearNightFaces() {
        let face = entries(F.night(), now: F.at(0, 21))[0].face
        #expect(face.flyOn == false)
        #expect(face.inline == "Fly off")
        #expect(face.detail == "Clear, dry, mild.")
        #expect(face.fetchedAt == F.at(0, 18))
    }

    @Test func packByHandsOverToTheNextNight() {
        let rainy = F.night { F.hour($0, chance: 0.5) }
        #expect(entries(F.night(), now: F.at(0, 21)).last?.face == .noForecast)
        #expect(entries(F.night(), now: F.at(0, 21), next: rainy).last?.face.flyOn == true)
    }
}
