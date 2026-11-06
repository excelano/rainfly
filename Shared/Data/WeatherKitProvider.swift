// WeatherKitProvider.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import CoreLocation
import Foundation
import WeatherKit

struct WeatherKitProvider: ForecastProvider {
    func night(at camp: CampLocation, evening: Date) async throws -> NightForecast {
        let calendar = NightWindow.localCalendar(for: camp)
        let morning = calendar.date(byAdding: .day, value: 1, to: evening)!
        // The day's hours warn of rain before the night starts; noon the next day ends dry-by.
        let hoursStart = evening
        let hoursEnd = calendar.date(byAdding: .hour, value: 13, to: morning)!
        let location = CLLocation(latitude: camp.latitude, longitude: camp.longitude)

        // WeatherKit dates its days in the location's own zone and may not return the last
        // day asked for, so the range is wide and the sun events are matched by time, not day.
        let (days, hours) = try await WeatherService.shared.weather(
            for: location,
            including: .daily(
                startDate: calendar.date(byAdding: .day, value: -1, to: evening)!,
                endDate: calendar.date(byAdding: .day, value: 3, to: evening)!
            ),
            .hourly(startDate: hoursStart, endDate: hoursEnd)
        )
        guard let sun = NightSun(
            sunsets: days.compactMap(\.sun.sunset), sunrises: days.compactMap(\.sun.sunrise),
            evening: evening, latitude: camp.latitude, calendar: calendar
        ) else {
            throw ForecastError.noSunset
        }

        return NightForecast(
            location: camp,
            fetchedAt: .now,
            sunset: sun.sunset,
            sunrise: sun.sunrise,
            hours: hours.map(Self.sample),
            polar: sun.polar
        )
    }

    func attribution() async throws -> Attribution {
        let attribution = try await WeatherService.shared.attribution
        return Attribution(markURL: attribution.combinedMarkDarkURL, legalURL: attribution.legalPageURL)
    }

    private static func sample(_ hour: HourWeather) -> HourSample {
        HourSample(
            date: hour.date,
            tempC: hour.temperature.converted(to: .celsius).value,
            dewPointC: hour.dewPoint.converted(to: .celsius).value,
            humidity: hour.humidity,
            cloudCover: hour.cloudCover,
            windMS: hour.wind.speed.converted(to: .metersPerSecond).value,
            gustMS: hour.wind.gust?.converted(to: .metersPerSecond).value,
            precipChance: hour.precipitationChance,
            precipAmountMM: hour.precipitationAmount.converted(to: .millimeters).value,
            isThunderstorm: stormConditions.contains(hour.condition)
        )
    }

    private static let stormConditions: Set<WeatherCondition> = [
        .isolatedThunderstorms, .scatteredThunderstorms, .thunderstorms, .strongStorms, .tropicalStorm, .hurricane,
    ]
}
