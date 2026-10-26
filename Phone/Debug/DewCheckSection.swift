// DewCheckSection.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

#if DEBUG
import SwiftUI

/// The dew log on the main screen: after sunrise, what was found on something left under
/// the sky; otherwise a line saying the log is recording.
struct DewCheckSection: View {
    let recorder: DewRecorder
    let night: DewLogNight?
    @State private var openSky = true

    var body: some View {
        Section {
            if let night {
                Toggle("Under open sky", isOn: $openSky)
                ForEach(DewObservation.Kind.allCases, id: \.self) { kind in
                    Button {
                        recorder.observe(kind, openSky: openSky, night: night)
                    } label: {
                        LabeledContent(Self.title(kind), value: Self.detail(kind))
                    }
                }
            } else {
                Text(status)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Dew log")
        } footer: {
            if let night {
                Text("\(night.campName == CampLocation.hereName ? "Last night" : "Last night at \(night.campName)"): check the same thing left under the sky each morning, not the inside of the tent.")
            }
        }
    }

    private var status: String {
        let nights = recorder.log.nights.count
        return "Recording forecasts. After sunrise, this asks what you found. \(nights == 1 ? "1 night" : "\(nights) nights") logged."
    }

    private static func title(_ kind: DewObservation.Kind) -> String {
        switch kind {
        case .dry: "Dry"
        case .lightDew: "Light dew"
        case .wet: "Wet"
        case .frost: "Frost"
        case .rain: "Rain"
        }
    }

    private static func detail(_ kind: DewObservation.Kind) -> String {
        switch kind {
        case .dry: "no moisture"
        case .lightDew: "spots or edges"
        case .wet: "damp all over or beaded"
        case .frost: "ice on it"
        case .rain: "it rained"
        }
    }
}
#endif
