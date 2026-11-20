// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
import Testing
@testable import Zeltwetter_Watch_App

private typealias F = Fixture

struct TripNightTextTests {
    private let tonight = NightDate(year: 2026, month: 7, day: 1)
    private let dewy = F.night { F.hour($0, temp: 12, dewPoint: 10, humidity: 0.9, wind: 1) }

    private func trip(_ latest: NightForecast, called: NightForecast? = nil, on date: NightDate? = nil, at now: Date) -> TripNightText {
        TripNightText(
            NightFetches(latest: latest, call: NightCall.seal(called ?? latest, settings: Settings())),
            of: TripNight(date: date ?? tonight, campName: F.camp.name), tonight: tonight,
            settings: Settings(), units: .locale, at: now
        )
    }

    @Test func tonightFollowsTheNight() {
        #expect(trip(dewy, at: F.at(0, 21)).phase == .evening)
        #expect(trip(dewy, at: F.at(1, 2)).phase == .overnight)
        #expect(trip(dewy, at: F.at(1, 7)).phase == .morning)
    }

    @Test func anotherNightShowsItsForecast() {
        let later = trip(dewy, called: F.night(), on: tonight.adding(days: 1), at: F.at(1, 7))
        #expect(later.phase == nil)
        #expect(later.row.flyOn == true)
        #expect(later.row.headline == "Rainfly on")
    }

    @Test func tonightsEveningRowIsTheVerdict() {
        let row = trip(dewy, at: F.at(0, 21)).row
        #expect(row.flyOn == true)
        #expect(row.headline == "Rainfly on")
    }

    @Test func tonightsOvernightRowNamesTheChangeSince22() {
        let rainLater = F.night { d in F.hour(d, temp: 12, dewPoint: 10, wind: 1, chance: d == F.at(1, 5) ? 0.4 : 0) }
        let row = trip(rainLater, called: dewy, at: F.at(1, 2)).row
        #expect(row.headline == "Rainfly on")
        #expect(row.detail.hasPrefix("New since "))
        #expect(row.detail.contains(": rain 40% at "))
    }

    @Test func tonightsMorningRowIsTheCall() {
        let row = trip(dewy, called: F.night(), at: F.at(1, 7)).row
        #expect(row.flyOn == false)
        #expect(row.headline == "Expected a dry night")
        #expect(row.detail == "Last night")
    }
}
