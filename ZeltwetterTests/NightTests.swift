// NightTests.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
import Testing
@testable import Zeltwetter_Watch_App

private typealias F = Fixture

struct NightSunTests {
    private func calendar(_ zone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar
    }

    private func at(_ calendar: Calendar, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    @Test func anOrdinaryNightTakesThatEveningsSunset() throws {
        let denver = calendar("America/Denver")
        let sun = try #require(NightSun(
            sunsets: [at(denver, 7, 1, 20, 30), at(denver, 7, 2, 20, 30)],
            sunrises: [at(denver, 7, 1, 5, 44), at(denver, 7, 2, 5, 45)],
            evening: at(denver, 7, 1, 0), latitude: 39.6, calendar: denver
        ))
        #expect(sun.sunset == at(denver, 7, 1, 20, 30))
        #expect(sun.sunrise == at(denver, 7, 2, 5, 45))
        #expect(sun.polar == nil)
    }

    @Test func aSunsetAfterMidnightBelongsToTheEveningBefore() throws {
        let reykjavik = calendar("Atlantic/Reykjavik")
        let sun = try #require(NightSun(
            sunsets: [at(reykjavik, 6, 21, 0, 3), at(reykjavik, 6, 22, 0, 4), at(reykjavik, 6, 23, 0, 4)],
            sunrises: [at(reykjavik, 6, 21, 2, 55), at(reykjavik, 6, 22, 2, 55), at(reykjavik, 6, 23, 2, 56)],
            evening: at(reykjavik, 6, 21, 0), latitude: 64.1, calendar: reykjavik
        ))
        #expect(sun.sunset == at(reykjavik, 6, 22, 0, 4))
        #expect(sun.sunrise == at(reykjavik, 6, 22, 2, 55))
        #expect(sun.polar == nil)

        let camp = CampLocation(name: "Thingvellir", latitude: 64.1, longitude: -21.1, timeZoneID: "Atlantic/Reykjavik")
        let night = NightForecast(location: camp, fetchedAt: .now, sunset: sun.sunset, sunrise: sun.sunrise, hours: [])
        #expect(ForecastCache.date(of: night) == NightDate(year: 2026, month: 6, day: 21))
    }

    @Test func midnightSunAndPolarNightRunFromNineToSix() throws {
        let tromso = calendar("Europe/Oslo")
        let summer = try #require(NightSun(sunsets: [], sunrises: [], evening: at(tromso, 6, 21, 0), latitude: 69.6, calendar: tromso))
        #expect(summer.sunset == at(tromso, 6, 21, 21))
        #expect(summer.sunrise == at(tromso, 6, 22, 6))
        #expect(summer.polar == .midnightSun)
        let winter = try #require(NightSun(sunsets: [], sunrises: [], evening: at(tromso, 12, 21, 0), latitude: 69.6, calendar: tromso))
        #expect(winter.polar == .polarNight)
        let antarctic = try #require(NightSun(sunsets: [], sunrises: [], evening: at(tromso, 6, 21, 0), latitude: -70, calendar: tromso))
        #expect(antarctic.polar == .polarNight)
    }

    @Test func aMissingSunsetAwayFromThePolesIsNotANight() {
        let denver = calendar("America/Denver")
        #expect(NightSun(sunsets: [], sunrises: [], evening: at(denver, 7, 1, 0), latitude: 39.6, calendar: denver) == nil)
    }
}

struct NightWindowEndTests {
    @Test func theNightEndsAtBreakCampWhenThatComesBeforeSunrise() {
        let window = NightWindow(F.night(), packByMinutes: 5 * 60)
        #expect(window.nightHours.last?.date == F.at(1, 4))
        #expect(window.morningHours.isEmpty)
    }

    @Test func aPolarNightSaysSoAndNamesItsHours() {
        let night = F.night()
        let polar = NightForecast(
            location: night.location, fetchedAt: night.fetchedAt, sunset: F.at(0, 21), sunrise: F.at(1, 6),
            hours: night.hours, polar: .midnightSun
        )
        let text = VerdictText(
            night: polar, verdict: FlyEngine.evaluate(polar, settings: Settings()), settings: Settings(),
            units: DisplayUnits(fahrenheit: false, mph: false), locale: Locale(identifier: "en_US")
        )
        #expect(text.notes(at: F.at(0, 20)).first == "The sun stays up all night here")
        #expect(text.rule(.rain).replacingOccurrences(of: "\u{202F}", with: " ").hasPrefix("If any hour from 9 PM to 6 AM has"))
    }
}

struct NightAtTheCampTests {
    private let chicago = TimeZone(identifier: "America/Chicago")!

    private func at(_ zone: String, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar.date(from: DateComponents(year: 2026, month: 7, day: day, hour: hour, minute: minute))!
    }

    private func trip(_ zone: String) -> Camps {
        var camps = Camps()
        let camp = camps.add(CampLocation(name: "Away", latitude: 0, longitude: 0, timeZoneID: zone))
        camps.plan(camp.name, on: NightDate(year: 2026, month: 7, day: 1))
        return camps
    }

    @Test func withoutATripTheDevicesPackByDecides() {
        let camps = Camps()
        #expect(camps.night(at: at("America/Chicago", 2, 11), deviceZone: chicago) == NightDate(year: 2026, month: 7, day: 1))
        #expect(camps.night(at: at("America/Chicago", 2, 13), deviceZone: chicago) == NightDate(year: 2026, month: 7, day: 2))
    }

    @Test func aCampAheadOfTheDeviceMovesOnAtItsOwnNoon() {
        let camps = trip("Pacific/Auckland")
        #expect(camps.night(at: at("Pacific/Auckland", 2, 11, 30), deviceZone: chicago) == NightDate(year: 2026, month: 7, day: 1))
        #expect(camps.night(at: at("Pacific/Auckland", 2, 12, 30), deviceZone: chicago) == NightDate(year: 2026, month: 7, day: 2))
    }

    @Test func aCampBehindTheDeviceKeepsItsNightUntilItsOwnNoon() {
        let camps = trip("Pacific/Honolulu")
        #expect(camps.night(at: at("Pacific/Honolulu", 2, 9), deviceZone: chicago) == NightDate(year: 2026, month: 7, day: 1))
        #expect(camps.night(at: at("Pacific/Honolulu", 2, 12, 30), deviceZone: chicago) == NightDate(year: 2026, month: 7, day: 2))
    }
}

struct BeforeTonightTests {
    /// The fixture night with the day's hours from noon, and rain at 3 PM when asked.
    private func text(_ afternoon: (Date) -> HourSample = { F.hour($0) }) -> VerdictText {
        let night = F.night()
        let day = (12..<19).map { afternoon(F.at(0, $0)) }
        let withDay = NightForecast(
            location: night.location, fetchedAt: night.fetchedAt, sunset: night.sunset, sunrise: night.sunrise,
            hours: day + night.hours
        )
        return VerdictText(
            night: withDay, verdict: FlyEngine.evaluate(withDay, settings: Settings()), settings: Settings(),
            units: DisplayUnits(fahrenheit: false, mph: false), locale: Locale(identifier: "en_US")
        )
    }

    private func plain(_ string: String?) -> String? {
        string?.replacingOccurrences(of: "\u{202F}", with: " ")
    }

    @Test func rainBeforeSunsetIsAHeadsUpNotAVerdict() {
        let rainy = text { F.hour($0, chance: $0 == F.at(0, 15) ? 0.6 : 0) }
        #expect(rainy.verdict.flyOn == false)
        #expect(plain(rainy.beforeTonightText(at: F.at(0, 9))) == "Rain 60% at 3 PM, before tonight's forecast starts")
        #expect(plain(rainy.beforeTonightBrief(at: F.at(0, 9))) == "Rain 3 PM")
        #expect(rainy.beforeTonightText(at: F.at(0, 16)) == nil)

        let stormy = text { F.hour($0, storm: $0 == F.at(0, 14)) }
        #expect(plain(stormy.beforeTonightText(at: F.at(0, 9))) == "Storms possible at 2 PM, before tonight's forecast starts")
        #expect(text().beforeTonightText(at: F.at(0, 9)) == nil)
    }

    @Test func theNightIsNamedBeforeSunset() {
        let words = text()
        #expect(plain(words.periodLabel(at: F.at(0, 9))) == "Tonight · sunset 8:30 PM to 8 AM")
        #expect(words.periodLabel(at: F.at(0, 21)) == "Tonight")
        #expect(words.periodLabel(at: F.at(1, 7)) == "This morning")
        #expect(words.headline(at: F.at(0, 9)) == "Rainfly off tonight")
        #expect(words.headline(at: F.at(1, 7)) == "Rainfly off")
    }

    @Test func theFaceLeadsWithRainBeforeTonight() {
        let rainy = text { F.hour($0, chance: $0 == F.at(0, 15) ? 0.6 : 0) }
        let face = ComplicationFace(rainy, at: F.at(0, 9))
        #expect(face.headline == "Rainfly off tonight")
        #expect(plain(face.detail) == "Rain 60% at 3 PM, before tonight's forecast starts")
        #expect(plain(face.inline) == "Rain 3 PM, before tonight")
        #expect(face.notes.first == rainy.reason)
        #expect(ComplicationFace(rainy, at: F.at(0, 21)).inline == "Rainfly off tonight")
    }
}
