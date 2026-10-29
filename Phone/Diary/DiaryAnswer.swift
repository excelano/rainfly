// DiaryAnswer.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

/// The answers to "what did you find?", for the morning question and for the diary screen.
struct DiaryAnswerRows: View {
    let recorder: DiaryRecorder
    let night: DiaryNight
    var answered: () -> Void = {}
    @State private var found: DewObservation.Kind?

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
        } else {
            ForEach(DewObservation.Kind.allCases, id: \.self) { kind in
                Button {
                    if kind == .rain || kind == .notChecked {
                        record(kind, openSky: night.observation?.openSky ?? true)
                    } else {
                        found = kind
                    }
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

    private func record(_ kind: DewObservation.Kind, openSky: Bool) {
        recorder.observe(kind, openSky: openSky, night: night)
        found = nil
        answered()
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
