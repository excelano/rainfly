// DiaryAnswer.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

/// The morning review: what Rainfly expected, and whether it was right. A night forecast to
/// rain asks about the rain first; only a wrong dew forecast asks what was found and where.
struct DiaryAnswerRows: View {
    @Environment(ForecastModel.self) private var model
    let recorder: DiaryRecorder
    let night: DiaryNight
    var answered: () -> Void = {}
    @State private var correcting = false
    @State private var rainAnswered = false
    @State private var found: DewObservation.Kind?

    /// Nil when no forecast was kept for the night, which leaves nothing to review.
    private var judgement: DiaryJudgement? {
        night.judge(settingsAt: model.settings(at:))
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
        } else if let judgement, let rain = judgement.rain, !rainAnswered, !correcting {
            Text(Self.rainExpectation(rain, in: night))
                .font(.headline)
            answer("Yes, it rained", chosen: night.observation?.kind == .rain) { record(.rain, openSky: openSky) }
            answer("No, it didn't rain", chosen: night.observation.map { ![.rain, .notChecked].contains($0.kind) } ?? false) {
                rainAnswered = true
            }
            answer(DewObservation.Kind.notChecked) { record(.notChecked, openSky: openSky) }
        } else if let judgement, !correcting {
            Text(Self.expectation(judgement.firing, in: night))
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

    static func expectation(_ expected: Firing?, in night: DiaryNight) -> String {
        guard let expected else { return "Rainfly expected no dew or frost. Was it right?" }
        return "Rainfly expected \(expected.trigger == .frost ? "frost" : "dew") by \(clock(expected, in: night)). Was it right?"
    }

    static func rainExpectation(_ rain: Firing, in night: DiaryNight) -> String {
        "Rainfly expected \(rain.trigger == .storm ? "a storm" : "rain") by \(clock(rain, in: night)). Did it rain?"
    }

    static func clock(_ firing: Firing, in night: DiaryNight) -> String {
        VerdictText.clock(firing.at, in: night.forecasts.first?.location.timeZone ?? .current)
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

/// The dew diary on the morning screen: the review until it is answered, then the answer set
/// against the forecast, and the suggested dew setting when the diary has one.
struct MorningDiarySection: View {
    @Environment(ForecastModel.self) private var model
    let recorder: DiaryRecorder
    let night: DiaryNight

    var body: some View {
        if night.observation == nil {
            MorningCheckSection(recorder: recorder, night: night)
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
            } header: {
                Text("Dew diary")
            }
        }
        if let suggestion = recorder.diary.suggestedDewSpread(settings: model.settings, units: model.preferences.units) {
            SuggestionSection(suggestion: suggestion, units: model.preferences.units) {
                model.settings.dewSpreadC = suggestion.suggested.spreadC
            }
        }
    }

    private var result: (title: String, detail: String) {
        let tally = recorder.diary.tally(settingsAt: model.settings(at:))
        let record = tally.judged == 0 ? "" : "Rainfly has been right on \(tally.caught + tally.clear) of the \(tally.judged) mornings you found dry, wet or frosty."
        guard let observation = night.observation, let judgement = night.judge(settingsAt: model.settings(at:)) else {
            return ("Your answer is saved", record)
        }
        switch (observation.kind, judgement.outcome) {
        case (.notChecked, _): return ("You didn't check this morning", record)
        case (.rain, _) where judgement.rain == nil: return ("It rained, so this night doesn't count for dew", record)
        case (.rain, _): return ("It rained, as expected", "Rain nights don't count for dew. \(record)")
        case (.lightDew, _): return ("You found light dew", "Light dew doesn't count as right or wrong. \(record)")
        case (_, .caught?): return ("You found it \(observation.kind == .frost ? "frosty" : "wet"), as expected", record)
        case (_, .clear?): return ("You found it dry, as expected", record)
        case (_, .missed?): return ("You found it \(observation.kind == .frost ? "frosty" : "wet"), but Rainfly said no dew", "\(cause(judgement)) \(record)")
        case (_, .falseAlarm?): return ("You found it dry, but Rainfly expected dew", "\(cause(judgement)) \(record)")
        case (_, nil): return ("Your answer is saved", record)
        }
    }

    private func cause(_ judgement: DiaryJudgement) -> String {
        switch judgement.cause {
        case .forecast?: "The forecast got the night wrong, not your dew setting."
        case .settings?: "The forecast was right, but your dew setting called it wrong."
        case nil: "Rainfly will know why once Apple Weather's record of the night is in."
        }
    }
}
