// DewDiary.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// The camper's check of the dew forecast: every forecast fetched for a night, the same night
/// fetched again from WeatherKit's history the morning after, and what was found on something
/// left under the sky.
struct DewDiary: Codable, Equatable {
    var nights: [DiaryNight] = []

    /// Keeps `forecast` with the others for its camp and night, once per fetch.
    mutating func record(_ forecast: NightForecast) {
        let date = ForecastCache.date(of: forecast)
        if let index = index(of: forecast.location.name, on: date) {
            guard !nights[index].forecasts.contains(where: { $0.fetchedAt == forecast.fetchedAt }) else { return }
            nights[index].forecasts.append(forecast)
        } else {
            nights.append(DiaryNight(campName: forecast.location.name, date: date, forecasts: [forecast]))
        }
    }

    mutating func observe(_ observation: DewObservation, campName: String, on date: NightDate) {
        guard let index = index(of: campName, on: date) else { return }
        nights[index].observation = observation
    }

    mutating func setHistory(_ history: NightForecast, campName: String, on date: NightDate) {
        guard let index = index(of: campName, on: date) else { return }
        nights[index].history = history
    }

    mutating func remove(campName: String, on date: NightDate) {
        nights.removeAll { $0.campName == campName && $0.date == date }
    }

    /// The night whose morning `now` is in, from sunrise until `answerWindow` after it, at
    /// the camp `campName` gives for that night, when it has no answer yet.
    func awaitingObservation(now: Date, campName: (NightDate) -> String) -> DiaryNight? {
        nights.last { night in
            guard night.campName == campName(night.date), night.observation == nil,
                  let sunrise = night.forecasts.last?.sunrise
            else { return false }
            return now >= sunrise && now < sunrise.addingTimeInterval(Self.answerWindow)
        }
    }

    /// Nights whose history is worth fetching at `now`: over, recent, and either not fetched
    /// yet or fetched so soon after sunrise that WeatherKit may since have revised the hours.
    func needingHistory(now: Date) -> [DiaryNight] {
        nights.filter { night in
            guard let sunrise = night.forecasts.last?.sunrise,
                  now >= sunrise.addingTimeInterval(Self.historyDelay),
                  now < sunrise.addingTimeInterval(Self.historyReach)
            else { return false }
            return night.history.map { $0.fetchedAt < sunrise.addingTimeInterval(Self.settledAfter) } ?? true
        }
    }

    func tally(settings: Settings) -> DiaryTally {
        var tally = DiaryTally()
        for night in nights {
            guard let kind = night.observation?.kind, let judgement = night.judge(settings: settings) else { continue }
            switch (judgement.outcome, kind) {
            case (.caught?, _): tally.caught += 1
            case (.clear?, _): tally.clear += 1
            case (.missed?, _): tally.missed += 1
            case (.falseAlarm?, _): tally.falseAlarms += 1
            case (nil, .lightDew):
                tally.lightDew += 1
                if judgement.predicted { tally.lightDewFlagged += 1 }
            default: break
            }
        }
        return tally
    }

    /// The dew spread that would have done best on the judged open-sky nights, tried at every
    /// value the setting can hold in `units`, when it beats the current one. Catching moisture
    /// counts first, fewer false alarms second, and nearness to the current value breaks ties.
    func suggestedDewSpread(settings: Settings, units: DisplayUnits) -> SpreadSuggestion? {
        let judged = nights.compactMap { night -> (forecast: NightForecast, wet: Bool)? in
            guard let observation = night.observation, observation.openSky,
                  let wet = observation.kind.foundMoisture, let forecast = night.pitched
            else { return nil }
            return (forecast, wet)
        }
        let wetNights = judged.filter(\.wet).count
        guard judged.count >= Self.suggestionNights, wetNights > 0, wetNights < judged.count else { return nil }

        let quantity = Quantity.dewSpread(units)
        let current = quantity.display(settings.dewSpreadC)
        func score(_ shown: Double) -> SpreadScore {
            var trial = settings
            trial.dewSpreadC = quantity.stored(shown)
            var score = SpreadScore(spreadC: trial.dewSpreadC, caught: 0, falseAlarms: 0)
            for night in judged where DiaryNight.predictsMoisture(night.forecast, settings: trial) {
                if night.wet { score.caught += 1 } else { score.falseAlarms += 1 }
            }
            return score
        }
        let candidates = stride(from: quantity.range.lowerBound, through: quantity.range.upperBound + quantity.step / 2, by: quantity.step)
            .map { (shown: $0, score: score($0)) }
        guard let best = candidates.min(by: { a, b in
            (b.score.caught, a.score.falseAlarms, abs(a.shown - current)) < (a.score.caught, b.score.falseAlarms, abs(b.shown - current))
        }) else { return nil }
        let now = score(current)
        guard abs(best.shown - current) > quantity.step / 2,
              (best.score.caught, -best.score.falseAlarms) > (now.caught, -now.falseAlarms)
        else { return nil }
        return SpreadSuggestion(suggested: best.score, current: now, wetNights: wetNights)
    }

    private func index(of campName: String, on date: NightDate) -> Int? {
        nights.firstIndex { $0.campName == campName && $0.date == date }
    }

    static let answerWindow: TimeInterval = 14 * 3600
    static let historyDelay: TimeInterval = 2 * 3600
    static let settledAfter: TimeInterval = 12 * 3600
    static let historyReach: TimeInterval = 5 * 86_400
    static let suggestionNights = 5
}

struct DiaryNight: Codable, Equatable {
    let campName: String
    let date: NightDate
    var forecasts: [NightForecast]
    var history: NightForecast?
    var observation: DewObservation?
    /// Set once the night has been shared with Excelano.
    var shared: SharedMark?

    /// The forecast that decided the fly: the last one fetched before sunset, or else the first.
    var pitched: NightForecast? {
        guard let first = forecasts.first else { return nil }
        return forecasts.last { $0.fetchedAt < first.sunset } ?? first
    }

    func judge(settings: Settings) -> DiaryJudgement? {
        guard let pitched else { return nil }
        let verdict = FlyEngine.evaluate(pitched, settings: settings)
        let firing = verdict.firing(.frost) ?? verdict.firing(.dew)
        let predicted = firing != nil
        var judgement = DiaryJudgement(
            predicted: predicted, firing: firing,
            closestSpread: NightWindow(pitched, packByMinutes: settings.packByMinutes).closestSpread
        )
        guard let found = observation?.kind.foundMoisture else { return judgement }
        judgement.outcome = switch (predicted, found) {
        case (true, true): .caught
        case (false, false): .clear
        case (false, true): .missed
        case (true, false): .falseAlarm
        }
        if predicted != found, let history {
            judgement.cause = Self.predictsMoisture(history, settings: settings) == found ? .forecast : .settings
        }
        return judgement
    }

    static func predictsMoisture(_ night: NightForecast, settings: Settings) -> Bool {
        let verdict = FlyEngine.evaluate(night, settings: settings)
        return verdict.firing(.dew) != nil || verdict.firing(.frost) != nil
    }
}

/// What was found in the morning on something left under the sky.
struct DewObservation: Codable, Equatable {
    /// Light dew is spots or edges; wet is damp all over or beaded, enough to pack a wet fly.
    enum Kind: String, Codable, CaseIterable {
        case dry, lightDew, wet, frost, rain, notChecked

        /// Whether the night counts as wet, dry, or neither when it is judged.
        var foundMoisture: Bool? {
            switch self {
            case .wet, .frost: true
            case .dry: false
            case .lightDew, .rain, .notChecked: nil
            }
        }
    }

    let kind: Kind
    /// False when what was checked stood under trees, which block most of the cooling.
    let openSky: Bool
    let at: Date
}

struct DiaryJudgement: Equatable {
    enum Outcome { case caught, clear, missed, falseAlarm }
    /// For a miss or a false alarm: whether WeatherKit's night was not the real one, or the
    /// thresholds called a correctly forecast night wrong.
    enum Cause { case forecast, settings }

    let predicted: Bool
    let firing: Firing?
    let closestSpread: Double?
    var outcome: Outcome?
    var cause: Cause?
}

struct DiaryTally: Equatable {
    var caught = 0
    var clear = 0
    var missed = 0
    var falseAlarms = 0
    var lightDew = 0
    var lightDewFlagged = 0

    var judged: Int { caught + clear + missed + falseAlarms }
}

struct SpreadScore: Equatable {
    let spreadC: Double
    var caught: Int
    var falseAlarms: Int
}

struct SpreadSuggestion: Equatable {
    let suggested: SpreadScore
    let current: SpreadScore
    let wetNights: Int
}

#if DEBUG
extension DewDiary {
    /// One row a night for checking the diary from a Mac: what was found, what the forecast
    /// said when the fly went on or not, and what the same checks make of the history.
    func report(settings: Settings) -> String {
        var rows = ["night,camp,found,open_sky,forecast_wet,forecast_at,forecast_spread,history_wet,history_at,history_spread,forecasts"]
        for night in nights.sorted(by: { ($0.date, $0.campName) < ($1.date, $1.campName) }) {
            guard let pitched = night.pitched else { continue }
            let forecast = Self.wetness(pitched, settings: settings)
            let history = night.history.map { Self.wetness($0, settings: settings) }
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
}
#endif
