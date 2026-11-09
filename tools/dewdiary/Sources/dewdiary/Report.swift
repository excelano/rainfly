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

    /// The open-sky nights that found moisture or none, which are the ones a check can be scored on.
    private static func judged(_ nights: [Night]) -> [Night] {
        nights.filter { $0.openSky && $0.found.foundMoisture != nil }
    }

    private static func header(_ judged: [Night]) -> String {
        let wet = judged.filter { $0.found.foundMoisture == true }.count
        return "\(judged.count) open-sky nights, \(wet) wet or frost and \(judged.count - wet) dry"
    }

    private struct Score {
        var caught = 0, alarms = 0, of = 0
    }

    /// How a check would have scored, with the engine deciding each night as `adjust` leaves
    /// it; a night `adjust` returns nil for is left out.
    private static func score(
        _ judged: [Night], _ nightOf: (Night) -> NightForecast?,
        adjust: (Night, NightForecast) -> (NightForecast, Settings)?
    ) -> Score {
        var score = Score()
        for night in judged {
            guard let original = nightOf(night), let (forecast, settings) = adjust(night, original) else { continue }
            score.of += 1
            guard DiaryJudging.predictsMoisture(forecast, settings: settings) else { continue }
            if night.found.foundMoisture == true { score.caught += 1 } else { score.alarms += 1 }
        }
        return score
    }

    /// How each dew spread would have done, with every other threshold as each camper had it:
    /// on the forecasts, which is what the setting acts on, and on the history, which takes the
    /// forecast's own errors out.
    static func sweep(_ nights: [Night]) -> String {
        let judged = judged(nights)
        guard !judged.isEmpty else { return "No open-sky nights with dry, wet or frost answers yet." }
        var lines = [header(judged), "spread °C   forecast: caught  false alarms   history: caught  false alarms"]
        for spread in stride(from: 0.5, through: 6.0, by: 0.5) {
            let adjust = { (night: Night, forecast: NightForecast) -> (NightForecast, Settings)? in
                var settings = night.settings
                settings.dewSpreadC = spread
                return (forecast, settings)
            }
            let forecast = score(judged, \.forecast, adjust: adjust), history = score(judged, \.history, adjust: adjust)
            let historyText = history.of == 0 ? "no history yet" : String(format: "%6d %13d", history.caught, history.alarms)
            lines.append(String(format: "%8.1f   %16d %13d   %@", spread, forecast.caught, forecast.alarms, historyText))
        }
        return lines.joined(separator: "\n")
    }

    /// How cloud limits that loosen as the air nears its dew point would have done: each
    /// camper's own limit at their dew spread, rising to the top at a 0.5° gap. The low-cloud
    /// rows count only low cloud, on the nights recorded with cloud by height. Each hour's
    /// cloud is scaled so that the engine's own test makes the comparison.
    static func cloudSweep(_ nights: [Night]) -> String {
        let judged = judged(nights)
        guard !judged.isEmpty else { return "" }
        var lines = ["cloud         at 0.5°   forecast: caught  false alarms  nights   history: caught  false alarms  nights"]
        for lowOnly in [false, true] {
            for top in [nil, 0.5, 0.6, 0.7] as [Double?] {
                let adjust = { (night: Night, forecast: NightForecast) -> (NightForecast, Settings)? in
                    let settings = night.settings
                    var hours: [HourSample] = []
                    for hour in forecast.hours {
                        var cloud = hour.cloudCover
                        if lowOnly {
                            guard let layers = hour.cloudLayers else { return nil }
                            cloud = layers.low
                        }
                        if let top { cloud *= settings.clearSky / limit(gap: hour.spreadC, top: top, settings) }
                        hours.append(hour.with(cloudCover: cloud))
                    }
                    return (forecast.with(hours: hours), settings)
                }
                let forecast = score(judged, \.forecast, adjust: adjust), history = score(judged, \.history, adjust: adjust)
                let name = (lowOnly ? "low only" : "all").padding(toLength: 14, withPad: " ", startingAt: 0)
                let topText = top.map { String(format: "%.0f%%", $0 * 100) } ?? "fixed"
                lines.append(name + String(repeating: " ", count: 7 - topText.count) + topText + String(
                    format: "   %16d %13d %7d   %15d %13d %7d",
                    forecast.caught, forecast.alarms, forecast.of, history.caught, history.alarms, history.of
                ))
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func limit(gap: Double, top: Double, _ settings: Settings) -> Double {
        let toward = min(max((settings.dewSpreadC - gap) / (settings.dewSpreadC - 0.5), 0), 1)
        return settings.clearSky + toward * (top - settings.clearSky)
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

private extension HourSample {
    func with(cloudCover: Double) -> HourSample {
        HourSample(
            date: date, tempC: tempC, dewPointC: dewPointC, humidity: humidity, cloudCover: cloudCover,
            cloudLayers: cloudLayers, windMS: windMS, gustMS: gustMS, precipChance: precipChance,
            precipAmountMM: precipAmountMM, isThunderstorm: isThunderstorm
        )
    }
}

private extension NightForecast {
    func with(hours: [HourSample]) -> NightForecast {
        var night = NightForecast(location: location, fetchedAt: fetchedAt, sunset: sunset, sunrise: sunrise, hours: hours)
        night.polar = polar
        return night
    }
}
