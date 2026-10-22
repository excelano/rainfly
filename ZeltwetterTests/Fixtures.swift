// Fixtures.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
@testable import Zeltwetter_Watch_App

/// A July night in Colorado: sunset 20:30, sunrise 05:45, hourly samples from 19:00 to
/// noon the next day. Every hour is clear, dry, mild and breezy unless a test says otherwise.
enum Fixture {
    static let camp = CampLocation(name: "Test Camp", latitude: 39.6, longitude: -105.9, timeZoneID: "America/Denver")

    static let calendar = NightWindow.localCalendar(for: camp)

    /// Local time at the camp; day 0 is the evening, day 1 the morning after.
    static func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: 1 + day, hour: hour, minute: minute))!
    }

    static let sunset = at(0, 20, 30)
    static let sunrise = at(1, 5, 45)
    static let hourDates = (0...17).map { at(0, 19).addingTimeInterval(TimeInterval($0) * 3600) }

    static func hour(
        _ date: Date,
        temp: Double = 15,
        dewPoint: Double = 5,
        humidity: Double = 0.5,
        cloud: Double = 0.1,
        wind: Double = 4,
        gust: Double? = nil,
        chance: Double = 0,
        amount: Double = 0,
        storm: Bool = false
    ) -> HourSample {
        HourSample(
            date: date, tempC: temp, dewPointC: dewPoint, humidity: humidity, cloudCover: cloud,
            windMS: wind, gustMS: gust, precipChance: chance, precipAmountMM: amount, isThunderstorm: storm
        )
    }

    /// The night with each hour built by `sample`, which gets the hour's start date.
    static func night(_ sample: (Date) -> HourSample = { hour($0) }) -> NightForecast {
        NightForecast(
            location: camp, fetchedAt: at(0, 18), sunset: sunset, sunrise: sunrise,
            hours: hourDates.map(sample)
        )
    }

    /// Dew all night (spread 2 °C, clear, calm), then `morning` from the hour holding sunrise on.
    static func dewyNight(temp: Double = 12, morning: @escaping (Date) -> HourSample) -> NightForecast {
        night { date in
            date < at(1, 5) ? hour(date, temp: temp, dewPoint: temp - 2, humidity: 0.9, wind: 1) : morning(date)
        }
    }
}
