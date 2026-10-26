// DewLog.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

#if DEBUG
import Foundation

/// A Debug-only record for checking the dew forecast against what happened: every forecast
/// fetched for a night, the same night's hours fetched again from WeatherKit's history the
/// morning after, and what the camper found. It lives in the App Group as dewlog.json, and is
/// pulled off a device with devicectl rather than shown in the app.
struct DewLog: Codable, Equatable {
    var nights: [DewLogNight] = []

    /// Keeps `forecast` with the others for its camp and night, once per fetch.
    mutating func record(_ forecast: NightForecast) {
        let date = ForecastCache.date(of: forecast)
        if let index = nights.firstIndex(where: { $0.campName == forecast.location.name && $0.date == date }) {
            guard !nights[index].forecasts.contains(where: { $0.fetchedAt == forecast.fetchedAt }) else { return }
            nights[index].forecasts.append(forecast)
        } else {
            nights.append(DewLogNight(campName: forecast.location.name, date: date, forecasts: [forecast]))
        }
    }

    mutating func observe(_ observation: DewObservation, campName: String, on date: NightDate) {
        guard let index = nights.firstIndex(where: { $0.campName == campName && $0.date == date }) else { return }
        nights[index].observation = observation
    }

    mutating func setActual(_ actual: NightForecast, campName: String, on date: NightDate) {
        guard let index = nights.firstIndex(where: { $0.campName == campName && $0.date == date }) else { return }
        nights[index].actual = actual
    }

    /// The night whose morning `now` is in, from sunrise until the evening, at the camp
    /// `campName` gives for that night, when it has no answer yet.
    func awaitingObservation(now: Date, campName: (NightDate) -> String) -> DewLogNight? {
        nights.last { night in
            guard night.campName == campName(night.date), night.observation == nil,
                  let sunrise = night.forecasts.last?.sunrise
            else { return false }
            return now >= sunrise && now < sunrise.addingTimeInterval(Self.answerWindow)
        }
    }

    /// Nights whose history is worth fetching at `now`: over, recent, and either not fetched
    /// yet or fetched so soon after sunrise that WeatherKit may since have revised the hours.
    func needingActuals(now: Date) -> [DewLogNight] {
        nights.filter { night in
            guard let sunrise = night.forecasts.last?.sunrise,
                  now >= sunrise.addingTimeInterval(Self.historyDelay),
                  now < sunrise.addingTimeInterval(Self.historyReach)
            else { return false }
            return night.actual.map { $0.fetchedAt < sunrise.addingTimeInterval(Self.settledAfter) } ?? true
        }
    }

    /// One row a night: what the camper found, what the forecast said when the tent went up
    /// (the last fetch before sunset), and what the same checks make of WeatherKit's history
    /// of the night. A wrong forecast shows as the two spreads far apart; a wrong rule shows
    /// as the history's verdict disagreeing with what was found.
    func report(settings: Settings) -> String {
        var rows = ["night,camp,found,open_sky,forecast_wet,forecast_at,forecast_spread,history_wet,history_at,history_spread,forecasts"]
        for night in nights.sorted(by: { ($0.date, $0.campName) < ($1.date, $1.campName) }) {
            guard let first = night.forecasts.first else { continue }
            let pitched = night.forecasts.last { $0.fetchedAt < first.sunset } ?? first
            let forecast = Self.wetness(pitched, settings: settings)
            let history = night.actual.map { Self.wetness($0, settings: settings) }
            let date = String(format: "%04d-%02d-%02d", night.date.year, night.date.month, night.date.day)
            let fields: [String] = [
                date, night.campName, night.observation?.kind.rawValue ?? "",
                night.observation.map { $0.openSky ? "yes" : "no" } ?? "",
                forecast.kind, forecast.at, forecast.spread,
                history?.kind ?? "", history?.at ?? "", history?.spread ?? "",
                String(night.forecasts.count),
            ]
            rows.append(fields.map(Self.csv).joined(separator: ","))
        }
        return rows.joined(separator: "\n") + "\n"
    }

    /// Whether the checks find dew or frost in `night`, the hour they first fire, and the
    /// closest the air comes to its dew point.
    private static func wetness(_ night: NightForecast, settings: Settings) -> (kind: String, at: String, spread: String) {
        let verdict = FlyEngine.evaluate(night, settings: settings)
        let firing = verdict.firing(.frost) ?? verdict.firing(.dew)
        let spread = NightWindow(night, packByMinutes: settings.packByMinutes).closestSpread
        var style = Date.FormatStyle().hour(.twoDigits(amPM: .omitted)).minute()
        style.timeZone = night.location.timeZone
        return (
            firing.map { $0.trigger.rawValue } ?? "dry",
            firing.map { $0.at.formatted(style) } ?? "",
            spread.map { String(format: "%.1f", $0) } ?? ""
        )
    }

    private static func csv(_ field: String) -> String {
        field.contains(",") || field.contains("\"") ? "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : field
    }

    static let answerWindow: TimeInterval = 14 * 3600
    static let historyDelay: TimeInterval = 2 * 3600
    static let settledAfter: TimeInterval = 12 * 3600
    static let historyReach: TimeInterval = 5 * 86_400
}

struct DewLogNight: Codable, Equatable {
    let campName: String
    let date: NightDate
    var forecasts: [NightForecast]
    var actual: NightForecast?
    var observation: DewObservation?
}

/// What the camper found in the morning on something left under the sky.
struct DewObservation: Codable, Equatable {
    enum Kind: String, Codable, CaseIterable {
        case dry, dew, frost, rain
    }

    let kind: Kind
    /// False when what was checked stood under trees, which block most of the cooling.
    let openSky: Bool
    let at: Date
}
#endif
