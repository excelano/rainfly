// SettingsTests.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
import Testing
@testable import Zeltwetter_Watch_App

struct SettingsTests {
    @Test func savedSettingsMissingAFieldKeepTheDefault() throws {
        let saved = Data(#"{"rainChance":0.4,"packByMinutes":540}"#.utf8)
        let settings = try JSONDecoder().decode(Settings.self, from: saved)
        var expected = Settings()
        expected.rainChance = 0.4
        expected.packByMinutes = 540
        #expect(settings == expected)
    }

    @Test func settingsRoundTrip() throws {
        var settings = Settings()
        settings.coldC = 4
        settings.bagRatingC = -3
        #expect(try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(settings)) == settings)
    }

    @Test func resetKeepsPackByAndBag() {
        var settings = Settings()
        settings.rainChance = 0.5
        settings.calmWindMS = 1
        settings.packByMinutes = 7 * 60 + 30
        settings.bagRatingC = 2
        var expected = Settings()
        expected.packByMinutes = 7 * 60 + 30
        expected.bagRatingC = 2
        #expect(settings.resettingThresholds() == expected)
    }

    @Test func preferencesMissingAFieldKeepTheDefault() throws {
        let saved = Data(#"{"units":{"fahrenheit":true,"mph":true}}"#.utf8)
        let preferences = try JSONDecoder().decode(Preferences.self, from: saved)
        #expect(preferences.units == DisplayUnits(fahrenheit: true, mph: true))
        #expect(preferences.pressureWatch)
    }

    @Test func storeStartsAtDefaultsAndKeepsWhatIsSaved() {
        let store = temporarySettings()
        #expect(store.settings == Settings())
        #expect(store.preferences.pressureWatch)

        var settings = Settings()
        settings.windRainMS = 10
        store.settings = settings
        var preferences = Preferences()
        preferences.units = DisplayUnits(fahrenheit: true, mph: false)
        preferences.pressureWatch = false
        store.preferences = preferences

        let reopened = SettingsStore(defaults: store.defaults)
        #expect(reopened.settings == settings)
        #expect(reopened.preferences == preferences)
    }

    @Test func unitConversions() {
        let us = DisplayUnits(fahrenheit: true, mph: true)
        #expect(us.temperature(10) == 50)
        #expect(us.celsius(50) == 10)
        #expect(abs(us.temperatureSpan(3) - 5.4) < 1e-9)
        #expect(abs(us.celsiusSpan(5.4) - 3) < 1e-9)
        #expect(abs(us.speed(8) - 17.8954) < 1e-3)
        #expect(abs(us.metersPerSecond(us.speed(8)) - 8) < 1e-9)

        let metric = DisplayUnits(fahrenheit: false, mph: false)
        #expect(metric.temperature(10) == 10)
        #expect(metric.speed(8) == 8)
        #expect(metric.speedUnit == "m/s")
    }

    @Test func quantitiesSnapToTheirStepAndRange() {
        let us = DisplayUnits(fahrenheit: true, mph: true)
        let metric = DisplayUnits(fahrenheit: false, mph: false)
        #expect(Quantity.rainChance.display(0.2) == 20)
        #expect(Quantity.rainChance.stored(35) == 0.35)
        #expect(Quantity.windRain(us).display(8) == 18)
        #expect(Quantity.windRain(metric).display(8.2) == 8)
        #expect(Quantity.cold(metric).display(30) == 20)
        #expect(Quantity.cold(us).display(10) == 50)
        #expect(Quantity.dewSpread(metric).text(3) == "3.0°")
        #expect(Quantity.calmWind(us).text(3) == "7 mph")
    }
}

@MainActor
struct SettingsModelTests {
    @Test func changesAreSavedAndReloaded() {
        let store = temporarySettings()
        let model = ForecastModel(provider: NoProvider(), cache: ForecastCache(store: Store(url: .temporaryDirectory.appending(path: UUID().uuidString))), store: store) {
            throw ForecastError.noLocation
        }
        model.settings.coldC = 5
        model.preferences.pressureWatch = false
        #expect(store.settings.coldC == 5)
        #expect(!store.preferences.pressureWatch)
    }
}

private struct NoProvider: ForecastProvider {
    func night(at camp: CampLocation, evening: Date) async throws -> NightForecast { throw ForecastError.noLocation }
    func attribution() async throws -> Attribution { .fallback }
}
