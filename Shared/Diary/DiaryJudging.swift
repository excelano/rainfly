// DiaryJudging.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// How a diary night is judged, using the engine alone, so the app and the dewdiary tool that
/// reads shared nights judge them the same way.
enum DiaryJudging {
    /// `pitched` is the forecast the fly was decided on; `history` is WeatherKit's account of
    /// the night after it was over.
    static func judge(_ pitched: NightForecast, history: NightForecast?, found kind: DewObservation.Kind?, settings: Settings) -> DiaryJudgement {
        let verdict = FlyEngine.evaluate(pitched, settings: settings)
        let firing = verdict.firing(.frost) ?? verdict.firing(.dew)
        let predicted = firing != nil
        var judgement = DiaryJudgement(
            predicted: predicted, firing: firing,
            closestSpread: NightWindow(pitched, packByMinutes: settings.packByMinutes).closestSpread
        )
        guard let found = kind?.foundMoisture else { return judgement }
        judgement.outcome = switch (predicted, found) {
        case (true, true): .caught
        case (false, false): .clear
        case (false, true): .missed
        case (true, false): .falseAlarm
        }
        if predicted != found, let history {
            judgement.cause = predictsMoisture(history, settings: settings) == found ? .forecast : .settings
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
