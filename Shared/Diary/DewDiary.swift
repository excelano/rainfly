// DewDiary.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// The camper's check of the dew forecast: each night's call and what was found on something
/// left under the sky. Beside them it tracks the night as it went: every forecast fetched for
/// it, and the same night fetched again from WeatherKit's history the morning after.
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

    func night(campName: String, on date: NightDate) -> DiaryNight? {
        index(of: campName, on: date).map { nights[$0] }
    }

    mutating func observe(_ observation: DewObservation, campName: String, on date: NightDate) {
        guard let index = index(of: campName, on: date) else { return }
        nights[index].observation = observation
    }

    /// Where the last answer before `date` was checked, since a right forecast doesn't ask
    /// and most people check the same spot each morning.
    func lastOpenSky(before date: NightDate) -> Bool {
        nights
            .filter { $0.date < date && $0.observation != nil }
            .max { $0.date < $1.date }?
            .observation?.openSky ?? true
    }

    /// Keeps the night's call, unless it already has one made from a later forecast.
    mutating func setCall(_ call: NightCall) {
        guard let index = index(of: call.forecast.location.name, on: ForecastCache.date(of: call.forecast)),
              call.supersedes(nights[index].call) else { return }
        nights[index].call = call
    }

    mutating func setHistory(_ history: NightForecast, campName: String, on date: NightDate) {
        guard let index = index(of: campName, on: date) else { return }
        nights[index].history = history
    }

    mutating func remove(campName: String, on date: NightDate) {
        nights.removeAll { $0.campName == campName && $0.date == date }
    }

    /// The night whose morning `now` is in, from its `answerOpens` until `answerWindow` after
    /// sunrise, at the camp `campName` gives for that night, when it has no answer yet.
    func awaitingObservation(now: Date, campName: (NightDate) -> String) -> DiaryNight? {
        nights.last { night in
            guard night.campName == campName(night.date), night.observation == nil,
                  let opens = night.answerOpens, let sunrise = night.forecasts.last?.sunrise
            else { return false }
            return now >= opens && now < sunrise.addingTimeInterval(Self.answerWindow)
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

    var tally: DiaryTally {
        var tally = DiaryTally()
        for night in nights {
            guard let kind = night.observation?.kind, let judgement = night.judgement else { continue }
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
        let judged = openSkyNights
        let wetNights = judged.filter(\.wet).count
        guard canSuggest else { return nil }

        let quantity = Quantity.dewSpread(units)
        let current = quantity.display(settings.dewSpreadC)
        func score(_ shown: Double) -> SpreadScore {
            var trial = settings
            trial.dewSpreadC = quantity.stored(shown)
            var score = SpreadScore(spreadC: trial.dewSpreadC, caught: 0, falseAlarms: 0)
            for night in judged where DiaryJudging.predictsMoisture(night.forecast, settings: trial) {
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

    var openSkyCounts: (wet: Int, dry: Int) {
        let wet = openSkyNights.filter(\.wet).count
        return (wet, openSkyNights.count - wet)
    }

    var canSuggest: Bool {
        let counts = openSkyCounts
        return counts.wet + counts.dry >= Self.suggestionNights && counts.wet > 0 && counts.dry > 0
    }

    private var openSkyNights: [(forecast: NightForecast, wet: Bool)] {
        nights.compactMap { night in
            guard let observation = night.observation, observation.openSky,
                  let wet = observation.kind.foundMoisture, let call = night.call
            else { return nil }
            return (call.forecast, wet)
        }
    }

    private func index(of campName: String, on date: NightDate) -> Int? {
        nights.firstIndex { $0.campName == campName && $0.date == date }
    }

    static let answerWindow: TimeInterval = 14 * 3600
    static let earlyAnswer: TimeInterval = 2 * 3600
    /// How long after sunrise WeatherKit's hours for the night are taken as its history.
    static let historyDelay: TimeInterval = 2 * 3600
    static let settledAfter: TimeInterval = 12 * 3600
    static let historyReach: TimeInterval = 5 * 86_400
    static let suggestionNights = 5
}

struct DiaryNight: Codable, Equatable {
    let campName: String
    let date: NightDate
    /// The night's call; nil until it is sealed, and for a night with no forecast before the anchor.
    var call: NightCall?
    /// Every fetch of the night, kept as a record of how the forecast moved.
    var forecasts: [NightForecast]
    var history: NightForecast?
    var observation: DewObservation?
    /// Set once the night has been shared with Excelano.
    var shared: SharedMark?

    /// When the morning question opens: `DewDiary.earlyAnswer` before sunrise, for a camper
    /// up before the sun.
    var answerOpens: Date? {
        forecasts.last.map { $0.sunrise.addingTimeInterval(-DewDiary.earlyAnswer) }
    }

    /// Nil for a night with no call, which leaves nothing to judge.
    var judgement: DiaryJudgement? {
        call.map { DiaryJudging.judge($0, found: observation?.kind) }
    }
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
    /// One row a night for checking the diary from a Mac: what was found, what the night's call
    /// said, and what the same checks make of the history.
    var report: String {
        var rows = ["night,camp,found,open_sky,forecast_wet,forecast_at,forecast_spread,history_wet,history_at,history_spread,forecasts"]
        for night in nights.sorted(by: { ($0.date, $0.campName) < ($1.date, $1.campName) }) {
            guard let call = night.call else { continue }
            let forecast = Self.wetness(call)
            let history = night.history.map { Self.wetness(NightCall($0, settings: call.settings)) }
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

    private static func wetness(_ call: NightCall) -> (kind: String, at: String, spread: String) {
        let firing = call.verdict.condensation
        let spread = call.closestSpread
        let calendar = NightWindow.localCalendar(for: call.forecast.location)
        let time = { (date: Date) in
            let parts = calendar.dateComponents([.hour, .minute], from: date)
            return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
        }
        return (
            firing.map { $0.trigger.rawValue } ?? "dry",
            firing.map { time($0.at) } ?? "",
            spread.map { String(format: "%.1f", $0) } ?? ""
        )
    }

    private static func csv(_ field: String) -> String {
        field.contains(",") || field.contains("\"") ? "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : field
    }
}
#endif
