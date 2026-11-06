// DiaryAnswer.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

/// The morning review: what Rainfly expected, and whether it was right. Only a wrong
/// forecast asks what was found and where.
struct DiaryAnswerRows: View {
    @Environment(ForecastModel.self) private var model
    let recorder: DiaryRecorder
    let night: DiaryNight
    var answered: () -> Void = {}
    @State private var correcting = false
    @State private var found: DewObservation.Kind?

    /// Nil when no forecast was kept for the night, which leaves nothing to review.
    private var judgement: DiaryJudgement? {
        night.judge(settings: model.settings)
    }

    var body: some View {
        if let found {
            Text("Where was it?")
                .font(.headline)
            Button {
                record(found, openSky: true)
            } label: {
                LabeledContent("Under open sky") { Text("nothing overhead") }
            }
            Button {
                record(found, openSky: false)
            } label: {
                LabeledContent("Under cover") { Text("trees, a roof or an awning") }
            }
            Button("Back") { self.found = nil }
        } else if let judgement, !correcting {
            Text(Self.expectation(judgement.firing, in: night))
                .font(.headline)
            answer("Yes, it was right", chosen: night.observation?.kind == Self.kind(for: judgement.firing)) {
                record(Self.kind(for: judgement.firing), openSky: recorder.diary.lastOpenSky(before: night.date))
            }
            answer("No, it was wrong", chosen: isCorrection(judgement)) { correcting = true }
            answer(DewObservation.Kind.rain) { record(.rain, openSky: openSky) }
            answer(DewObservation.Kind.notChecked) { record(.notChecked, openSky: openSky) }
        } else {
            Text("What did you find?")
                .font(.headline)
            ForEach(choices, id: \.self) { kind in
                answer(kind) { found = kind }
            }
            if judgement != nil {
                Button("Back") { correcting = false }
            }
        }
    }

    /// After "it was wrong", only what the forecast did not expect.
    private var choices: [DewObservation.Kind] {
        let found: [DewObservation.Kind] = [.dry, .lightDew, .wet, .frost]
        guard let judgement else { return found + [.rain, .notChecked] }
        return found.filter { $0.foundMoisture != judgement.predicted }
    }

    private func isCorrection(_ judgement: DiaryJudgement) -> Bool {
        guard let kind = night.observation?.kind, kind != .rain, kind != .notChecked else { return false }
        return kind != Self.kind(for: judgement.firing)
    }

    private var openSky: Bool { night.observation?.openSky ?? true }

    private func answer(_ title: String, chosen: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            LabeledContent(title) {
                if chosen {
                    Image(systemName: "checkmark")
                        .accessibilityLabel("Chosen")
                }
            }
        }
    }

    private func answer(_ kind: DewObservation.Kind, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            LabeledContent {
                if night.observation?.kind == kind {
                    Image(systemName: "checkmark")
                        .accessibilityLabel("Chosen")
                } else {
                    Text(kind.detail)
                }
            } label: {
                Text(kind.title)
            }
        }
    }

    private func record(_ kind: DewObservation.Kind, openSky: Bool) {
        recorder.observe(kind, openSky: openSky, night: night)
        found = nil
        correcting = false
        answered()
    }

    /// What a right forecast means was found: frost, wet, or dry.
    static func kind(for expected: Firing?) -> DewObservation.Kind {
        switch expected?.trigger {
        case .frost?: .frost
        case nil: .dry
        default: .wet
        }
    }

    static func expectation(_ expected: Firing?, in night: DiaryNight) -> String {
        guard let expected else { return "Rainfly expected no dew or frost. Was it right?" }
        let time = VerdictText.clock(expected.at, in: night.forecasts.first?.location.timeZone ?? .current)
        return "Rainfly expected \(expected.trigger == .frost ? "frost" : "dew") by \(time). Was it right?"
    }
}

extension DewObservation.Kind {
    var title: String {
        switch self {
        case .dry: "Dry"
        case .lightDew: "Light dew"
        case .wet: "Wet"
        case .frost: "Frost"
        case .rain: "Rain"
        case .notChecked: "Didn't check"
        }
    }

    var detail: String {
        switch self {
        case .dry: "no moisture"
        case .lightDew: "spots or edges"
        case .wet: "damp all over or beaded"
        case .frost: "ice on it"
        case .rain: "it rained"
        case .notChecked: "skip this night"
        }
    }
}

/// The morning question on the main screen, between the verdict and the checks.
struct MorningCheckSection: View {
    let recorder: DiaryRecorder
    let night: DiaryNight

    var body: some View {
        Section {
            DiaryAnswerRows(recorder: recorder, night: night)
        } header: {
            Text("Dew diary")
        } footer: {
            Text("\(night.campName == CampLocation.hereName ? "Last night" : "Last night at \(night.campName)"): check the same thing left under the sky each morning, not the inside of the tent.")
        }
    }
}
