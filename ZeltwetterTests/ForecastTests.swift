// ForecastTests.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
import Testing
@testable import Zeltwetter_Watch_App

private typealias F = Fixture

struct NightWindowTests {
    @Test func eveningIsLastNightUntilPackBy() {
        let evening = { (now: Date) in NightWindow.evening(at: now, packByMinutes: 8 * 60, calendar: F.calendar) }
        let july1 = F.calendar.startOfDay(for: F.at(0, 12))
        let july2 = F.calendar.startOfDay(for: F.at(1, 12))
        #expect(evening(F.at(0, 21)) == july1)
        #expect(evening(F.at(1, 3)) == july1)
        #expect(evening(F.at(1, 7, 59)) == july1)
        #expect(evening(F.at(1, 8)) == july2)
        #expect(evening(F.at(1, 15)) == july2)
    }

    @Test func summaryCoversTheNightAndMorningRain() {
        let night = F.night { d in
            switch d {
            case F.at(0, 19): F.hour(d, temp: 2, dewPoint: 1, chance: 0.9)
            case F.at(1, 3): F.hour(d, temp: 7, dewPoint: 4)
            case F.at(1, 7): F.hour(d, temp: 3, dewPoint: 3, chance: 0.6)
            default: F.hour(d)
            }
        }
        let window = NightWindow(night, packByMinutes: 8 * 60)
        #expect(window.low == 7)
        #expect(window.closestSpread == 3)
        #expect(window.maxPrecipChance == 0.6)
    }
}

struct VerdictTextTests {
    private func text(_ night: NightForecast, _ settings: Settings = Settings(), fahrenheit: Bool = false) -> VerdictText {
        let units = DisplayUnits(fahrenheit: fahrenheit, mph: false)
        return VerdictText(
            night: night, verdict: FlyEngine.evaluate(night, settings: settings), settings: settings,
            units: units, locale: Locale(identifier: "en_US")
        )
    }

    /// Recent ICU puts a narrow no-break space before AM and PM.
    private func plain(_ string: String) -> String {
        string.replacingOccurrences(of: "\u{202F}", with: " ")
    }

    @Test func clearNightReads() {
        let words = text(F.night())
        #expect(words.headline == "Fly off")
        #expect(words.reason == "Clear, dry, mild.")
        #expect(words.notes.isEmpty)
    }

    @Test func reasonsNameTheHeadlineAndItsTime() {
        let rain = text(F.night { d in F.hour(d, chance: d == F.at(1, 2) ? 0.35 : 0) })
        #expect(rain.headline == "Fly on")
        #expect(plain(rain.reason) == "Rain 35% after 2 AM")

        let storm = text(F.night { d in F.hour(d, storm: d == F.at(0, 23)) })
        #expect(plain(storm.reason) == "Storms possible at 11 PM")

        let morning = text(F.night { d in F.hour(d, chance: d == F.at(1, 7) ? 0.4 : 0) })
        #expect(plain(morning.reason) == "Morning rain 40% at 7 AM")

        let cold = text(F.night { F.hour($0, temp: 8, dewPoint: 0) })
        #expect(plain(cold.reason) == "Below 10° by 8 PM")
        let coldF = text(F.night { F.hour($0, temp: 8, dewPoint: 0) }, fahrenheit: true)
        #expect(plain(coldF.reason) == "Below 50° by 8 PM")
    }

    @Test func notesForDewThatDries() {
        var settings = Settings()
        settings.bagRatingC = 15
        let words = text(F.dewyNight { F.hour($0, temp: 15, dewPoint: 5) }, settings)
        #expect(plain(words.reason) == "Dew likely by 8 PM")
        #expect(words.notes.map(plain) == ["Open the vents", "Below your bag rating: wear layers", "Dry by ~6:45 AM"])
    }

    @Test func notesForDewThatStaysWet() {
        let words = text(F.dewyNight { F.hour($0, temp: 10, dewPoint: 9.5, cloud: 1, wind: 0) })
        #expect(words.notes == ["Open the vents", "Won't dry by noon"])
    }

    @Test func briefAndCompactTimes() {
        let words = text(F.night { F.hour($0, temp: 12, dewPoint: 10, wind: 1) })
        #expect(plain(words.brief(words.verdict.headline!)) == "Dew 8 PM")
        #expect(words.compactClock(F.at(1, 6, 45)) == "6:45")
        #expect(words.compactClock(F.at(0, 20, 5)) == "8:05")
        #expect(words.compactClock(F.at(1, 0, 30)) == "12:30")

        var german = words
        german.locale = Locale(identifier: "de_DE")
        #expect(german.compactClock(F.at(1, 6, 45)) == "06:45")
        #expect(german.compactClock(F.at(0, 20, 5)) == "20:05")
    }

    @Test func spreadConvertsWithoutTheOffset() {
        let words = text(F.night(), fahrenheit: true)
        #expect(words.degrees(0) == "32°")
        #expect(words.degreeSpan(2) == "4°")
    }

    @Test func forecastAgeAndStaleness() {
        let night = F.night()
        let fetched = night.fetchedAt
        #expect(VerdictText.age(since: fetched, at: fetched.addingTimeInterval(20)) == "Forecast just now")
        #expect(VerdictText.age(since: fetched, at: fetched.addingTimeInterval(25 * 60)) == "Forecast 25 min old")
        #expect(VerdictText.age(since: fetched, at: fetched.addingTimeInterval(6.5 * 3600)) == "Forecast 6 h old")
        #expect(VerdictText.staleness(since: fetched, at: fetched.addingTimeInterval(12 * 3600)) == .fresh)
        #expect(VerdictText.staleness(since: fetched, at: fetched.addingTimeInterval(13 * 3600)) == .aging)
        #expect(VerdictText.staleness(since: fetched, at: fetched.addingTimeInterval(25 * 3600)) == .stale)
    }
}

func temporarySettings() -> SettingsStore {
    let name = "zeltwetter-\(UUID().uuidString)"
    return SettingsStore(defaults: UserDefaults(suiteName: name)!)
}

private func temporaryCache() -> ForecastCache {
    let url = FileManager.default.temporaryDirectory.appending(path: "zeltwetter-\(UUID().uuidString).json")
    return ForecastCache(store: Store(url: url))
}

struct ForecastCacheTests {
    private let july1 = F.calendar.startOfDay(for: F.at(0, 12))

    @Test func savesAndFindsTheNightByCampAndEvening() {
        let cache = temporaryCache()
        let night = F.night()
        cache.save(night, now: F.at(0, 18))
        #expect(cache.night(at: F.camp.name, evening: july1) == night)
        #expect(cache.night(at: "Elsewhere", evening: july1) == nil)
        #expect(cache.night(at: F.camp.name, evening: F.calendar.startOfDay(for: F.at(1, 12))) == nil)
    }

    @Test func aNewFetchReplacesTheSameNight() {
        let cache = temporaryCache()
        cache.save(F.night(), now: F.at(0, 18))
        let rainy = F.night { F.hour($0, chance: 0.5) }
        cache.save(rainy, now: F.at(0, 19))
        #expect(cache.night(at: F.camp.name, evening: july1) == rainy)
        #expect(cache.store.load()?.count == 1)
    }

    @Test func oldNightsAreDropped() {
        let cache = temporaryCache()
        cache.save(F.night(), now: F.at(0, 18))
        let otherCamp = CampLocation(name: "Ridge", latitude: 40, longitude: -106, timeZoneID: F.camp.timeZoneID)
        let later = NightForecast(location: otherCamp, fetchedAt: F.at(2, 6), sunset: F.at(2, 20), sunrise: F.at(3, 5), hours: [])
        cache.save(later, now: F.at(2, 6))
        #expect(cache.store.load() == [later])
    }
}

private actor FakeProvider: ForecastProvider {
    let fetchedAt: Date
    private(set) var fetches = 0
    var chance = 0.0

    init(fetchedAt: Date) {
        self.fetchedAt = fetchedAt
    }

    func night(at camp: CampLocation, evening: Date) async throws -> NightForecast {
        fetches += 1
        let calendar = NightWindow.localCalendar(for: camp)
        let at = { (hours: Int) in calendar.date(byAdding: .hour, value: hours, to: evening)! }
        return NightForecast(
            location: camp, fetchedAt: fetchedAt, sunset: at(20), sunrise: at(30),
            hours: (19...36).map { F.hour(at($0), chance: chance) }
        )
    }

    func attribution() async throws -> Attribution {
        Attribution(markURL: nil, legalURL: URL(string: "https://example.com/legal")!)
    }

    func setChance(_ value: Double) { chance = value }
}

@MainActor
struct ForecastModelTests {
    let here = CampLocation(name: CampLocation.hereName, latitude: 39.6, longitude: -105.9, timeZoneID: TimeZone.current.identifier)
    let afternoon = Calendar.current.date(bySettingHour: 15, minute: 0, second: 0, of: .now)!

    @Test func emptyCacheFetchesAndEvaluates() async {
        let provider = FakeProvider(fetchedAt: afternoon)
        let cache = temporaryCache()
        let model = ForecastModel(provider: provider, cache: cache, store: temporarySettings()) { [here] in here }
        await model.refreshIfStale(now: afternoon)
        #expect(await provider.fetches == 1)
        #expect(model.verdict?.flyOn == false)
        #expect(model.attribution.legalURL.host() == "example.com")
        #expect(cache.night(at: CampLocation.hereName, evening: Calendar.current.startOfDay(for: afternoon)) != nil)
    }

    @Test func freshCacheIsNotRefetched() async {
        let provider = FakeProvider(fetchedAt: afternoon)
        let cache = temporaryCache()
        let model = ForecastModel(provider: provider, cache: cache, store: temporarySettings()) { [here] in here }
        await model.refreshIfStale(now: afternoon)
        await model.refreshIfStale(now: afternoon.addingTimeInterval(ForecastModel.refreshAge - 60))
        #expect(await provider.fetches == 1)
    }

    @Test func staleCacheIsRefetched() async {
        let provider = FakeProvider(fetchedAt: afternoon)
        let cache = temporaryCache()
        let model = ForecastModel(provider: provider, cache: cache, store: temporarySettings()) { [here] in here }
        await model.refreshIfStale(now: afternoon)
        await provider.setChance(0.5)
        await model.refreshIfStale(now: afternoon.addingTimeInterval(ForecastModel.refreshAge + 60))
        #expect(await provider.fetches == 2)
        #expect(model.verdict?.flyOn == true)
    }

    @Test func failedFetchKeepsTheCachedNight() async {
        let provider = FakeProvider(fetchedAt: afternoon)
        let cache = temporaryCache()
        await ForecastModel(provider: provider, cache: cache, store: temporarySettings()) { [here] in here }.refreshIfStale(now: afternoon)

        let offline = ForecastModel(provider: provider, cache: cache, store: temporarySettings()) { throw ForecastError.noLocation }
        await offline.refreshIfStale(now: afternoon.addingTimeInterval(ForecastModel.refreshAge + 60))
        #expect(offline.night != nil)
        #expect(offline.problem == ForecastError.noLocation.localizedDescription)
    }

    @Test func settingsChangesReevaluate() async {
        let provider = FakeProvider(fetchedAt: afternoon)
        await provider.setChance(0.3)
        let model = ForecastModel(provider: provider, cache: temporaryCache(), store: temporarySettings()) { [here] in here }
        await model.refreshIfStale(now: afternoon)
        #expect(model.verdict?.flyOn == true)
        model.settings.rainChance = 0.4
        model.settings.morningRainChance = 0.4
        #expect(model.verdict?.flyOn == false)
    }
}
