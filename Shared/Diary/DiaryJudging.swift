// DiaryJudging.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// How a diary night is judged, using the engine alone, so the app and the dewdiary tool that
/// reads shared nights judge them the same way.
enum DiaryJudging {
    /// The night's call against what was found on something left under the sky.
    static func judge(_ call: NightCall, found kind: DewObservation.Kind?) -> DiaryJudgement {
        let firing = call.verdict.condensation
        let predicted = firing != nil
        var judgement = DiaryJudgement(predicted: predicted, firing: firing, rain: call.verdict.rain, closestSpread: call.closestSpread)
        guard let found = kind?.foundMoisture else { return judgement }
        judgement.outcome = switch (predicted, found) {
        case (true, true): .caught
        case (false, false): .clear
        case (false, true): .missed
        case (true, false): .falseAlarm
        }
        return judgement
    }

    /// Whether `night` puts dew or frost in the overnight period under `settings`.
    static func predictsMoisture(_ night: NightForecast, settings: Settings) -> Bool {
        FlyEngine.overnight(night, settings: settings).condensation != nil
    }
}

struct DiaryJudgement: Equatable {
    enum Outcome { case caught, clear, missed, falseAlarm }

    let predicted: Bool
    let firing: Firing?
    let rain: Firing?
    let closestSpread: Double?
    var outcome: Outcome?
}
