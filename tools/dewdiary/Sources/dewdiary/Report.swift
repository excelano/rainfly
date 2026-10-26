// Report.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// A shared night read back from its record.
struct Night {
    let diary: String
    let night: String
    let latitude: Double
    let longitude: Double
    let found: DewObservation.Kind
    let openSky: Bool
    let appVersion: String
    let forecast: NightForecast
    let history: NightForecast?
    let settings: Settings

    init?(_ record: CloudRecord) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let diary = record.string("diary"), let night = record.string("night"),
              let latitude = record.number("latitude"), let longitude = record.number("longitude"),
              let zone = record.string("timeZone"),
              let found = record.string("found").flatMap(DewObservation.Kind.init),
              let forecast = record.string("forecast").flatMap({ try? decoder.decode(SharedHours.self, from: Data($0.utf8)) }),
              let settings = record.string("settings").flatMap({ try? decoder.decode(Settings.self, from: Data($0.utf8)) })
        else { return nil }
        self.diary = diary
        self.night = night
        self.latitude = latitude
        self.longitude = longitude
        self.found = found
        openSky = (record.number("openSky") ?? 1) != 0
        appVersion = record.string("appVersion") ?? ""
        self.forecast = forecast.night(latitude: latitude, longitude: longitude, timeZoneID: zone)
        history = record.string("history")
            .flatMap { try? decoder.decode(SharedHours.self, from: Data($0.utf8)) }
            .map { $0.night(latitude: latitude, longitude: longitude, timeZoneID: zone) }
        self.settings = settings
    }
}

enum Report {
    static func csv(_ nights: [Night]) -> String {
        var rows = ["diary,night,latitude,longitude,found,open_sky,app_version,forecast_wet,forecast_at,forecast_spread,history_wet,history_at,history_spread,outcome,cause"]
        for night in nights.sorted(by: { ($0.night, $0.diary) < ($1.night, $1.diary) }) {
            let judgement = DiaryJudging.judge(night.forecast, history: night.history, found: night.found, settings: night.settings)
            let history = night.history.map { DiaryJudging.judge($0, history: nil, found: nil, settings: night.settings) }
            let fields = [
                night.diary, night.night, String(night.latitude), String(night.longitude), night.found.rawValue,
                night.openSky ? "yes" : "no", night.appVersion,
                wet(judgement), clock(judgement.firing?.at, night.forecast), spread(judgement.closestSpread),
                history.map(wet) ?? "", clock(history?.firing?.at, night.forecast), spread(history?.closestSpread),
                judgement.outcome.map { "\($0)" } ?? "", judgement.cause.map { "\($0)" } ?? "",
            ]
            rows.append(fields.joined(separator: ","))
        }
        return rows.joined(separator: "\n") + "\n"
    }

    /// How each dew spread would have done on the open-sky nights that found moisture or none,
    /// with every other threshold as each camper had it: on the forecasts, which is what the
    /// setting acts on, and on the history, which takes the forecast's own errors out.
    static func sweep(_ nights: [Night]) -> String {
        let judged = nights.filter { $0.openSky && $0.found.foundMoisture != nil }
        let wet = judged.filter { $0.found.foundMoisture == true }.count
        guard !judged.isEmpty else { return "No open-sky nights with dry, wet or frost answers yet." }
        var lines = ["\(judged.count) open-sky nights, \(wet) wet or frost and \(judged.count - wet) dry", "spread °C   forecast: caught  false alarms   history: caught  false alarms"]
        for spread in stride(from: 0.5, through: 6.0, by: 0.5) {
            func score(_ nightOf: (Night) -> NightForecast?) -> (caught: Int, alarms: Int, of: Int) {
                var caught = 0, alarms = 0, of = 0
                for night in judged {
                    guard let forecast = nightOf(night) else { continue }
                    of += 1
                    var settings = night.settings
                    settings.dewSpreadC = spread
                    guard DiaryJudging.predictsMoisture(forecast, settings: settings) else { continue }
                    if night.found.foundMoisture == true { caught += 1 } else { alarms += 1 }
                }
                return (caught, alarms, of)
            }
            let forecast = score(\.forecast), history = score(\.history)
            let historyText = history.of == 0 ? "no history yet" : String(format: "%6d %13d", history.caught, history.alarms)
            lines.append(String(format: "%8.1f   %16d %13d   %@", spread, forecast.caught, forecast.alarms, historyText))
        }
        return lines.joined(separator: "\n")
    }

    private static func wet(_ judgement: DiaryJudgement) -> String {
        judgement.firing.map { $0.trigger.rawValue } ?? "dry"
    }

    private static func spread(_ value: Double?) -> String {
        value.map { String(format: "%.1f", $0) } ?? ""
    }

    private static func clock(_ date: Date?, _ night: NightForecast) -> String {
        guard let date else { return "" }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = night.location.timeZone
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }
}
