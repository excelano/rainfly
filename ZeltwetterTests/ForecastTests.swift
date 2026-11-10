// ForecastTests.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
import Testing
@testable import Zeltwetter_Watch_App

private typealias F = Fixture

struct NightWindowTests {
    @Test func nightIsLastNightUntilNoon() {
        let night = { (now: Date) in NightDate.covering(now, calendar: F.calendar) }
        let july1 = NightDate(year: 2026, month: 7, day: 1)
        let july2 = NightDate(year: 2026, month: 7, day: 2)
        #expect(night(F.at(0, 21)) == july1)
        #expect(night(F.at(1, 3)) == july1)
        #expect(night(F.at(1, 11, 59)) == july1)
        #expect(night(F.at(1, 12)) == july2)
        #expect(night(F.at(1, 15)) == july2)
    }

    @Test func theNightHasThreePhases() {
        let window = NightWindow(F.night(), packByMinutes: 8 * 60)
        #expect(window.anchor == F.at(0, 22))
        #expect(window.handover == F.at(1, 12))
        #expect(window.phase(at: F.at(0, 15)) == .evening)
        #expect(window.phase(at: F.at(0, 22)) == .overnight)
        #expect(window.phase(at: F.at(1, 5)) == .overnight)
        #expect(window.phase(at: F.sunrise) == .morning)
        #expect(window.phase(at: F.at(1, 11)) == .morning)
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

    @Test func periodFollowsThePhases() {
        let night = text(F.night())
        #expect(night.period(at: F.at(0, 21)) == "Tonight")
        #expect(night.period(at: F.at(0, 23)) == "Overnight")
        #expect(night.period(at: F.at(1, 3)) == "Overnight")
        #expect(night.period(at: F.at(1, 6)) == "This morning")
        #expect(night.period(at: F.at(1, 11)) == "This morning")
    }

    @Test func clearNightReads() {
        let words = text(F.night())
        #expect(words.headline == "Rainfly off")
        #expect(words.reason == "Clear, dry, mild.")
        #expect(words.notes(at: F.at(0, 21)).isEmpty)
    }

    @Test func reasonsNameTheHeadlineAndItsTime() {
        let rain = text(F.night { d in F.hour(d, chance: d == F.at(1, 2) ? 0.35 : 0) })
        #expect(rain.headline == "Rainfly on")
        #expect(plain(rain.reason) == "Rain 35% at 2 AM")

        let storm = text(F.night { d in F.hour(d, storm: d == F.at(0, 23)) })
        #expect(plain(storm.reason) == "Storms possible at 11 PM")

        let morning = text(F.night { d in F.hour(d, chance: d == F.at(1, 7) ? 0.4 : 0) })
        #expect(plain(morning.reason) == "Morning rain 40% at 7 AM")

        let cold = text(F.night { F.hour($0, temp: 8, dewPoint: 0) })
        #expect(plain(cold.reason) == "Below 10° by 8 PM: the rainfly holds warmth")
        let coldF = text(F.night { F.hour($0, temp: 8, dewPoint: 0) }, fahrenheit: true)
        #expect(plain(coldF.reason) == "Below 50° by 8 PM: the rainfly holds warmth")
    }

    @Test func dewAndFrostSayWhatDecidedThem() {
        let dew = text(F.night { F.hour($0, temp: 12, dewPoint: 10, wind: 1) })
        #expect(plain(dew.summary(.dew)) == "At 8 PM the air is 2.0° from its dew point, with a clear sky and little wind, so dew will form.")
        #expect(dew.summary(.frost) == "Frost would form, but the air stays warmer than 2°, so it will be dew instead.")

        let frost = text(F.night { F.hour($0, temp: -2, dewPoint: -4, wind: 1) })
        #expect(frost.summary(.dew) == "Dew would form, but the air is 2° or colder, so it will be frost instead.")

        let cloudy = text(F.night { F.hour($0, temp: 12, dewPoint: 10, cloud: 0.8, wind: 1) })
        #expect(cloudy.summary(.dew) == "The air gets within 2.0° of its dew point, but it's cloudy then. Clouds keep the tent from cooling down, so dew won't form.")
        let windy = text(F.night { F.hour($0, temp: 12, dewPoint: 10, wind: 4) })
        #expect(windy.summary(.dew) == "The air gets within 2.0° of its dew point, but it's windy then. Wind keeps the tent from cooling down, so dew won't form.")
        let both = text(F.night { d in F.hour(d, temp: 12, dewPoint: 10, cloud: d < F.at(1, 0) ? 0.8 : 0.1, wind: d < F.at(1, 0) ? 1 : 4) })
        #expect(both.summary(.dew) == "The air gets within 2.0° of its dew point, but whenever it does, it's either cloudy or windy, so dew won't form.")

        let dry = text(F.night())
        #expect(dry.summary(.dew) == "The air stays at least 10.0° from its dew point. It has to get within 3.0° for dew.")
        #expect(dew.rule(.dew) == "If, in the same hour, the air gets within 3.0° of its dew point, the sky is less than 30% cloudy, the wind is under 3.0 m/s, and the air is warmer than 2°, the rainfly goes on.")
    }

    @Test func rainSaysWhetherTheChanceOrTheRainDecidedIt() {
        let likely = text(F.night { d in F.hour(d, chance: d == F.at(1, 2) ? 0.35 : 0) })
        #expect(plain(likely.summary(.rain)) == "35% chance of rain at 2 AM. That's at or above the 20% limit.")
        let drizzle = text(F.night { d in F.hour(d, chance: 0.1, amount: d == F.at(1, 2) ? 0.2 : 0) })
        #expect(plain(drizzle.reason) == "Rain forecast at 2 AM")
        #expect(plain(drizzle.summary(.rain)) == "The chance is only 10%, but some rain is forecast to fall at 2 AM, so it counts.")
        let dry = text(F.night { F.hour($0, chance: 0.1) })
        #expect(dry.summary(.rain) == "The highest chance overnight is 10%. It has to reach 20%.")
        #expect(dry.summary(.morningRain) == "The highest chance before you pack up is 10%. It has to reach 20%.")
        #expect(text(F.night()).summary(.rain) == "No rain is forecast overnight.")
    }

    @Test func windWithRainSaysWhichWasMissing() {
        let both = text(F.night { d in F.hour(d, wind: d == F.at(1, 1) ? 10 : 4, chance: d == F.at(1, 1) ? 0.15 : 0) })
        #expect(plain(both.summary(.windRain)) == "Wind up to 10.0 m/s with a 15% chance of rain at 1 AM. Both are at or over the limits.")
        let dry = text(F.night { F.hour($0, wind: 10) })
        #expect(dry.summary(.windRain) == "Wind gets up to 10.0 m/s, but the chance of rain stays under 10% whenever it's that windy.")
        let calm = text(F.night())
        #expect(calm.summary(.windRain) == "Wind stays at 4.0 m/s or less. It has to go over 8.0 m/s.")
    }

    @Test func stormsAndColdSayWhatTheyFound() {
        let storm = text(F.night { d in F.hour(d, storm: d == F.at(0, 23)) })
        #expect(plain(storm.summary(.storm)) == "A thunderstorm is forecast at 11 PM.")
        #expect(text(F.night()).summary(.storm) == "No thunderstorms are forecast.")
        let cold = text(F.night { d in F.hour(d, temp: d < F.at(1, 3) ? 12 : 7, dewPoint: 0) })
        #expect(plain(cold.summary(.cold)) == "It gets colder than 10° by 3 AM and drops to 7°.")
        #expect(text(F.night()).summary(.cold) == "The lowest it gets is 15°. It has to drop below 10°.")
    }

    @Test func notesForDewThatDries() {
        var settings = Settings()
        settings.bagRatingC = 15
        let words = text(F.dewyNight { F.hour($0, temp: 15, dewPoint: 5) }, settings)
        #expect(plain(words.reason) == "Dew likely by 8 PM")
        #expect(words.notes(at: F.at(0, 21)).map(plain) == ["Open the vents: it's a damp, still night", "Wear layers: it gets colder than your sleeping bag is rated for", "Dry around 6:45 AM tomorrow"])
        #expect(words.notes(at: F.at(1, 2)).last.map(plain) == "Dry around 6:45 AM this morning")
        #expect(words.notes(at: F.at(-1, 21)).last.map(plain) == "Dry around 6:45 AM on Thursday")
    }

    @Test func notesForDewThatStaysWet() {
        let words = text(F.dewyNight { F.hour($0, temp: 10, dewPoint: 9.5, cloud: 1, wind: 0) })
        #expect(words.notes(at: F.at(0, 21)) == ["Open the vents: it's a damp, still night", "Won't dry before noon tomorrow"])
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
        #expect(german.clock(F.at(0, 20)) == "20:00")
    }

    @Test func spreadConvertsWithoutTheOffset() {
        let words = text(F.night(), fahrenheit: true)
        #expect(words.low(0) == "32°")
        #expect(words.spread(2) == "4°")
    }

    @Test func measuredValuesStayOnTheSideTheCheckSaw() {
        var settings = Settings()
        settings.dewSpreadC = 2.5
        settings.coldC = 10
        let words = text(F.night(), settings)
        #expect(words.spread(2.5) == "2.5°")
        #expect(words.spread(3.4) == "3.4°")
        #expect(words.spread(2.53) == "2.53°")
        #expect(words.low(9.6) == "9.6°")
        #expect(words.low(10.3) == "10.3°")
        #expect(words.low(12.4) == "12°")
        #expect(words.summary(.dew).hasSuffix("It has to get within 2.5° for dew."))
    }

    @Test func forecastAgeAndStaleness() {
        let night = F.night()
        let fetched = night.fetchedAt
        #expect(VerdictText.age(since: fetched, at: fetched.addingTimeInterval(20)) == "Forecast just now")
        #expect(VerdictText.age(since: fetched, at: fetched.addingTimeInterval(25 * 60)) == "Forecast 25 min old")
        #expect(VerdictText.age(since: fetched, at: fetched.addingTimeInterval(6.5 * 3600)) == "Forecast 6 h old")
        #expect(VerdictText.age(since: fetched, at: fetched.addingTimeInterval(47 * 3600)) == "Forecast 47 h old")
        #expect(VerdictText.age(since: fetched, at: fetched.addingTimeInterval(97 * 3600)) == "Forecast 4 days old")
        #expect(VerdictText.staleness(since: fetched, at: fetched.addingTimeInterval(12 * 3600)) == .fresh)
        #expect(VerdictText.staleness(since: fetched, at: fetched.addingTimeInterval(13 * 3600)) == .aging)
        #expect(VerdictText.staleness(since: fetched, at: fetched.addingTimeInterval(25 * 3600)) == .stale)
    }
}

/// Metric units, whose steps hold the default settings, so a test doesn't depend on the
/// simulator's region.
func temporarySettings() -> SettingsStore {
    let name = "zeltwetter-\(UUID().uuidString)"
    let store = SettingsStore(defaults: UserDefaults(suiteName: name)!)
    store.preferences.units = DisplayUnits(fahrenheit: false, mph: false)
    return store
}

func temporaryCamps() -> Store<Camps> {
    Store(url: FileManager.default.temporaryDirectory.appending(path: "zeltwetter-camps-\(UUID().uuidString).json"))
}

func temporaryCache() -> ForecastCache {
    let url = FileManager.default.temporaryDirectory.appending(path: "zeltwetter-\(UUID().uuidString).json")
    return ForecastCache(store: Store(url: url))
}

struct ForecastCacheTests {
    private let july1 = NightDate(year: 2026, month: 7, day: 1)

    @Test func savesAndFindsTheNightByCampAndEvening() {
        let cache = temporaryCache()
        let night = F.night()
        cache.save(night, now: F.at(0, 18))
        #expect(cache.night(at: F.camp.name, on: july1) == night)
        #expect(cache.night(at: "Elsewhere", on: july1) == nil)
        #expect(cache.night(at: F.camp.name, on: july1.adding(days: 1)) == nil)
    }

    @Test func aNightKeepsItsLatestItsDecidedAndItsLastBeforeMorning() {
        let cache = temporaryCache()
        let fetched = { (date: Date) in
            let night = F.night()
            return NightForecast(location: night.location, fetchedAt: date, sunset: night.sunset, sunrise: night.sunrise, hours: night.hours)
        }
        for date in [F.at(0, 18), F.at(0, 21, 30), F.at(0, 23), F.at(1, 5), F.at(1, 8)] {
            cache.save(fetched(date), now: date)
        }
        #expect(cache.night(at: F.camp.name, on: july1)?.fetchedAt == F.at(1, 8))
        #expect(cache.decided(at: F.camp.name, on: july1)?.fetchedAt == F.at(0, 21, 30))
        #expect(cache.beforeMorning(at: F.camp.name, on: july1)?.fetchedAt == F.at(1, 5))
        #expect(cache.store.load()?.count == 3)
    }

    @Test func aNightFirstFetchedAfterTenIsJudgedOnThatFetch() {
        let cache = temporaryCache()
        let night = F.night()
        let late = NightForecast(location: night.location, fetchedAt: F.at(1, 1), sunset: night.sunset, sunrise: night.sunrise, hours: night.hours)
        cache.save(late, now: F.at(1, 1))
        #expect(cache.decided(at: F.camp.name, on: july1) == late)
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

actor FakeProvider: ForecastProvider {
    let fetchedAt: Date
    private(set) var fetches = 0
    private(set) var campsFetched: [String] = []
    var chance = 0.0

    init(fetchedAt: Date) {
        self.fetchedAt = fetchedAt
    }

    func night(at camp: CampLocation, evening: Date) async throws -> NightForecast {
        fetches += 1
        campsFetched.append(camp.name)
        let calendar = NightWindow.localCalendar(for: camp)
        let at = { (hours: Int) in calendar.date(byAdding: .hour, value: hours, to: evening)! }
        return NightForecast(
            location: camp, fetchedAt: fetchedAt, sunset: at(20), sunrise: at(30),
            hours: (19...36).map { F.hour(at($0), chance: chance) }
        )
    }

    func current(at camp: CampLocation) async throws -> CurrentConditions {
        CurrentConditions(date: fetchedAt, tempC: 7, dewPointC: 5, cloudCover: 0.1, windMS: 1, isRaining: false)
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
        let model = ForecastModel(provider: provider, cache: cache, store: temporarySettings(), campStore: temporaryCamps()) { [here] in here }
        await model.refreshIfStale(now: afternoon)
        #expect(await provider.fetches == 1)
        #expect(model.verdict?.flyOn == false)
        #expect(model.attribution.legalURL.host() == "example.com")
        #expect(cache.night(at: CampLocation.hereName, on: NightDate(afternoon, calendar: .current)) != nil)
    }

    @Test func freshCacheIsNotRefetched() async {
        let provider = FakeProvider(fetchedAt: afternoon)
        let cache = temporaryCache()
        let model = ForecastModel(provider: provider, cache: cache, store: temporarySettings(), campStore: temporaryCamps()) { [here] in here }
        await model.refreshIfStale(now: afternoon)
        await model.refreshIfStale(now: afternoon.addingTimeInterval(ForecastModel.refreshAge - 60))
        #expect(await provider.fetches == 1)
    }

    @Test func staleCacheIsRefetched() async {
        let provider = FakeProvider(fetchedAt: afternoon)
        let cache = temporaryCache()
        let model = ForecastModel(provider: provider, cache: cache, store: temporarySettings(), campStore: temporaryCamps()) { [here] in here }
        await model.refreshIfStale(now: afternoon)
        await provider.setChance(0.5)
        await model.refreshIfStale(now: afternoon.addingTimeInterval(ForecastModel.refreshAge + 60))
        #expect(await provider.fetches == 2)
        #expect(model.verdict?.flyOn == true)
    }

    @Test func failedFetchKeepsTheCachedNight() async {
        let provider = FakeProvider(fetchedAt: afternoon)
        let cache = temporaryCache()
        await ForecastModel(provider: provider, cache: cache, store: temporarySettings(), campStore: temporaryCamps()) { [here] in here }.refreshIfStale(now: afternoon)

        let offline = ForecastModel(provider: provider, cache: cache, store: temporarySettings(), campStore: temporaryCamps()) { throw ForecastError.noLocation }
        await offline.refreshIfStale(now: afternoon.addingTimeInterval(ForecastModel.refreshAge + 60))
        #expect(offline.night != nil)
        #expect(offline.problem == ForecastError.noLocation.localizedDescription)
    }

    @Test func settingsChangesReevaluate() async {
        let provider = FakeProvider(fetchedAt: afternoon)
        await provider.setChance(0.3)
        let model = ForecastModel(provider: provider, cache: temporaryCache(), store: temporarySettings(), campStore: temporaryCamps()) { [here] in here }
        await model.refreshIfStale(now: afternoon)
        #expect(model.verdict?.flyOn == true)
        model.settings.rainChance = 0.4
        model.settings.morningRainChance = 0.4
        #expect(model.verdict?.flyOn == false)
    }
}
