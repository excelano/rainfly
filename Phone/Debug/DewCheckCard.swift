// DewCheckCard.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

#if DEBUG
import SwiftUI

/// The morning question for the dew log: what was found on something left under the sky.
struct DewCheckCard: View {
    let recorder: DewRecorder
    let night: DewLogNight
    @State private var openSky = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(night.campName == CampLocation.hereName ? "How was it outside last night?" : "How was it outside last night at \(night.campName)?")
                .font(.headline)
            Text("Check something left under the sky, like a windshield or a tarp, not the inside of the tent.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Toggle("Under open sky", isOn: $openSky)
            HStack {
                ForEach(DewObservation.Kind.allCases, id: \.self) { kind in
                    Button(Self.title(kind)) {
                        recorder.observe(kind, openSky: openSky, night: night)
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
        .padding(.horizontal)
    }

    private static func title(_ kind: DewObservation.Kind) -> String {
        switch kind {
        case .dry: "Dry"
        case .dew: "Dew"
        case .frost: "Frost"
        case .rain: "Rain"
        }
    }
}
#endif
