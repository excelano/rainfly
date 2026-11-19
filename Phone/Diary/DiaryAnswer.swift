// DiaryAnswer.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

/// The morning review: what Rainfly expected, and whether it was right. A night forecast to
/// rain asks about the rain first; only a wrong dew forecast asks what was found and where.
struct DiaryAnswerRows: View {
    let recorder: DiaryRecorder
    let night: DiaryNight
    /// Whether the screen's headline already says what Rainfly expected, as the morning's does.
    var underHeadline = false
    var answered: () -> Void = {}
    @State private var correcting = false
    @State private var rainAnswered = false
    @State private var found: DewObservation.Kind?

    /// Nil for a night with no call, which leaves nothing to review.
    private var judgement: DiaryJudgement? { night.judgement }

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
        } else if let judgement, let rain = judgement.rain, !rainAnswered, !correcting {
            Text(underHeadline ? "Did it rain?" : "\(MorningText.expected(rain)). Did it rain?")
                .font(.headline)
            answer("Yes, it rained", chosen: night.observation?.kind == .rain) { record(.rain, openSky: openSky) }
            answer("No, it didn't rain", chosen: night.observation.map { ![.rain, .notChecked].contains($0.kind) } ?? false) {
                rainAnswered = true
            }
            answer(DewObservation.Kind.notChecked) { record(.notChecked, openSky: openSky) }
        } else if let judgement, !correcting {
            Text(
                underHeadline && judgement.rain == nil
                    ? "Was it right?"
                    : "\(MorningText.expected(judgement.firing, afterRain: judgement.rain != nil)). Was it right?"
            )
                .font(.headline)
            answer("Yes, it was right", chosen: night.observation?.kind == Self.kind(for: judgement.firing)) {
                record(Self.kind(for: judgement.firing), openSky: recorder.diary.lastOpenSky(before: night.date))
            }
            answer("Partly: light dew", chosen: night.observation?.kind == .lightDew) {
                record(.lightDew, openSky: recorder.diary.lastOpenSky(before: night.date))
            }
            answer("No, it was wrong", chosen: isCorrection(judgement)) { correcting = true }
            if judgement.rain == nil {
                answer(DewObservation.Kind.rain) { record(.rain, openSky: openSky) }
            }
            answer(DewObservation.Kind.notChecked) { record(.notChecked, openSky: openSky) }
            if judgement.rain != nil {
                Button("Back") { rainAnswered = false }
            }
        } else {
            Text("What did you find?")
                .font(.headline)
            ForEach(choices, id: \.self) { kind in
                answer(kind) {
                    if kind == .rain || kind == .notChecked { record(kind, openSky: openSky) } else { found = kind }
                }
            }
            if judgement != nil {
                Button("Back") { correcting = false }
            }
        }
    }

    /// After "it was wrong", only what the forecast did not expect; light dew has its own answer.
    private var choices: [DewObservation.Kind] {
        guard let judgement else { return DewObservation.Kind.allCases }
        return [.dry, .wet, .frost].filter { $0.foundMoisture != judgement.predicted }
    }

    private func isCorrection(_ judgement: DiaryJudgement) -> Bool {
        guard let kind = night.observation?.kind, ![.lightDew, .rain, .notChecked].contains(kind) else { return false }
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
        rainAnswered = false
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

/// The morning question on the main screen.
struct MorningCheckSection: View {
    let recorder: DiaryRecorder
    let night: DiaryNight
    var underHeadline = false

    var body: some View {
        Section {
            DiaryAnswerRows(recorder: recorder, night: night, underHeadline: underHeadline)
        } header: {
            if !underHeadline {
                Text(night.campName == CampLocation.hereName ? "Last night" : "Last night at \(night.campName)")
            }
        } footer: {
            Text("Check the same thing left under the sky each morning, not the inside of the tent.")
        }
    }
}

/// Last night on the morning screen: the question until it is answered, then whether Rainfly
/// was right, and the suggested dew setting when the diary has one.
struct MorningDiarySection: View {
    @Environment(ForecastModel.self) private var model
    let recorder: DiaryRecorder
    let night: DiaryNight

    var body: some View {
        if night.observation == nil {
            MorningCheckSection(recorder: recorder, night: night, underHeadline: true)
        } else {
            Section {
                NavigationLink {
                    DiaryScreen(recorder: recorder)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.title).font(.headline)
                        Text(result.detail).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
        }
        if let suggestion = recorder.diary.suggestedDewSpread(settings: model.settings, units: model.preferences.units) {
            SuggestionSection(suggestion: suggestion, units: model.preferences.units) {
                model.settings.dewSpreadC = suggestion.suggested.spreadC
            }
        }
    }

    private var result: (title: String, detail: String) {
        let tally = recorder.diary.tally
        let record = tally.judged == 0 ? "" : "Rainfly has been right on \(tally.caught + tally.clear) of the \(tally.judged) mornings you found dry, wet or frosty."
        guard let observation = night.observation, let judgement = night.judgement else {
            return ("Your answer is saved", record)
        }
        switch (observation.kind, judgement.outcome) {
        case (.notChecked, _): return ("You didn't check this morning", record)
        case (.rain, _) where judgement.rain == nil: return ("It rained, so this night doesn't count for dew", record)
        case (.rain, _): return ("It rained, as expected", "Rain nights don't count for dew. \(record)")
        case (.lightDew, _): return ("You found light dew", "Light dew doesn't count as right or wrong. \(record)")
        case (_, .caught?), (_, .clear?): return ("Rainfly was right", Self.sentences("\(found(observation)).", record))
        case (_, .missed?), (_, .falseAlarm?):
            let expected = MorningText.expected(judgement.firing, afterRain: judgement.rain != nil)
            return ("Rainfly was wrong", Self.sentences("\(found(observation)), but \(expected).", record))
        case (_, nil): return ("Your answer is saved", record)
        }
    }

    private func found(_ observation: DewObservation) -> String {
        "You found it \(observation.kind == .frost ? "frosty" : observation.kind == .wet ? "wet" : "dry")"
    }

    private static func sentences(_ parts: String...) -> String {
        parts.filter { !$0.isEmpty }.joined(separator: " ")
    }

}
