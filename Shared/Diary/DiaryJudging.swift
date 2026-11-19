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
        let firing = verdict.condensation
        let predicted = firing != nil
        var judgement = DiaryJudgement(
            predicted: predicted, firing: firing, rain: verdict.rain,
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
        FlyEngine.evaluate(night, settings: settings).condensation != nil
    }
}

struct DiaryJudgement: Equatable {
    enum Outcome { case caught, clear, missed, falseAlarm }
    /// For a miss or a false alarm: whether WeatherKit's night was not the real one, or the
    /// thresholds called a correctly forecast night wrong.
    enum Cause { case forecast, settings }

    let predicted: Bool
    let firing: Firing?
    let rain: Firing?
    let closestSpread: Double?
    var outcome: Outcome?
    var cause: Cause?
}
