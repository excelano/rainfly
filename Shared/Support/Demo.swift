// Demo.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

#if DEBUG
import Foundation

/// Debug launch arguments for screenshots and simulator checks, which run without
/// WeatherKit or a location:
///
///     --demo clear|rain|storm|dew|frost   a two-night trip whose first camp has a night
///                                         that gives that verdict; the second night is
///                                         already downloaded
///     --open detail|settings|camps        also opens that screen; the iPhone shows the
///                                         detail on its main screen, so it opens only
///                                         settings and camps
enum Demo {
    static var scene: String? { argument(after: "--demo") }
    static var opens: String? { argument(after: "--open") }

    private static func argument(after flag: String) -> String? {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }

    static let camp = CampLocation(
        name: "Lost Lake", latitude: 39.9389, longitude: -105.6106, timeZoneID: TimeZone.current.identifier
    )
    static let nextCamp = CampLocation(
        name: "Arapaho Pass", latitude: 39.9746, longitude: -105.6492, timeZoneID: TimeZone.current.identifier
    )

    @MainActor
    static func model(scene: String) -> ForecastModel {
        let url = FileManager.default.temporaryDirectory.appending(path: "demo-forecasts.json")
        try? FileManager.default.removeItem(at: url)
        let defaults = UserDefaults(suiteName: "demo")!
        defaults.removePersistentDomain(forName: "demo")
        let tonight = NightDate.covering(.now, packByMinutes: Settings().packByMinutes, calendar: .current)
        var camps = Camps()
        camps.add(camp)
        camps.add(nextCamp)
        camps.plan(camp.name, on: tonight)
        camps.plan(nextCamp.name, on: tonight.adding(days: 1))
        let campStore = Store<Camps>(url: FileManager.default.temporaryDirectory.appending(path: "demo-camps.json"))
        campStore.save(camps)
        let provider = Provider(scene: scene)
        let cache = ForecastCache(store: Store(url: url))
        let calendar = NightWindow.localCalendar(for: nextCamp)
        cache.save(provider.makeNight(at: nextCamp, evening: tonight.adding(days: 1).start(in: calendar), scene: "clear"))
        return ForecastModel(
            provider: provider, cache: cache,
            store: SettingsStore(defaults: defaults), campStore: campStore
        ) { CampLocation(name: CampLocation.hereName, latitude: camp.latitude, longitude: camp.longitude, timeZoneID: camp.timeZoneID) }
    }

    /// Hours from 19:00 on the evening to noon the next day; sunset 20:30, sunrise 06:10.
    private struct Provider: ForecastProvider {
        let scene: String

        func night(at camp: CampLocation, evening: Date) async throws -> NightForecast {
            makeNight(at: camp, evening: evening, scene: scene)
        }

        func makeNight(at camp: CampLocation, evening: Date, scene: String) -> NightForecast {
            let calendar = NightWindow.localCalendar(for: camp)
            let at = { (minutes: Int) in calendar.date(byAdding: .minute, value: minutes, to: evening)! }
            return NightForecast(
                location: camp,
                fetchedAt: .now.addingTimeInterval(-3 * 3600),
                sunset: at(20 * 60 + 30),
                sunrise: at(30 * 60 + 10),
                hours: (19...36).map { sample(at(60 * $0), hour: $0, scene: scene) }
            )
        }

        func attribution() async throws -> Attribution { .fallback }

        private func sample(_ date: Date, hour: Int, scene: String) -> HourSample {
            let morning = hour >= 30
            var temp = 14.0, dewPoint = 6.0, cloud = 0.2, wind = 4.0, chance = 0.0, storm = false
            switch scene {
            case "rain":
                chance = hour == 26 ? 0.35 : hour > 26 && !morning ? 0.25 : 0
                cloud = 0.8
            case "storm":
                storm = hour == 23
                chance = hour == 23 ? 0.3 : 0
            case "dew":
                if !morning && hour >= 27 { temp = 9; dewPoint = 7; cloud = 0.1; wind = 1 }
            case "frost":
                if !morning { temp = -2; dewPoint = -4; cloud = 0.05; wind = 0.5 } else { temp = 4; dewPoint = -3 }
            default:
                break
            }
            return HourSample(
                date: date, tempC: temp, dewPointC: dewPoint, humidity: morning ? 0.6 : 0.88, cloudCover: cloud,
                windMS: wind, gustMS: nil, precipChance: chance, precipAmountMM: 0, isThunderstorm: storm
            )
        }
    }
}
#endif
