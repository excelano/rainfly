// DiaryAnswer.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

/// The answers to "what did you find?", for the morning question and for the diary screen.
struct DiaryAnswerRows: View {
    let recorder: DiaryRecorder
    let night: DiaryNight
    var answered: () -> Void = {}
    @State private var openSky: Bool

    init(recorder: DiaryRecorder, night: DiaryNight, answered: @escaping () -> Void = {}) {
        self.recorder = recorder
        self.night = night
        self.answered = answered
        _openSky = State(initialValue: night.observation?.openSky ?? true)
    }

    var body: some View {
        Toggle("Under open sky", isOn: $openSky)
        ForEach(DewObservation.Kind.allCases, id: \.self) { kind in
            Button {
                recorder.observe(kind, openSky: openSky, night: night)
                answered()
            } label: {
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
