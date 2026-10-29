// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

struct WelcomeScreen: View {
    let start: (CampLocation?) -> Void
    @State private var isAddingCamp = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    TentGlyph(flyOn: true)
                        .frame(height: 96)
                        .foregroundStyle(Color.accentColor)
                        .frame(maxWidth: .infinity)
                    Text("Rainfly")
                        .font(.largeTitle.bold())
                        .frame(maxWidth: .infinity)
                    Beat(symbol: "tent", title: "Should the rain fly go on tonight?",
                         detail: "Rainfly reads the night's forecast for your campsite and answers with Rainfly on or Rainfly off, and the reason.")
                    Beat(symbol: "checklist", title: "Seven checks",
                         detail: "Storms, rain, wind-driven rain, frost, dew, morning rain and cold. Any one of them puts the fly on. Tap a check to see why it matters.")
                    Beat(symbol: "antenna.radiowaves.left.and.right.slash", title: "Ready offline",
                         detail: "Forecasts stay on your iPhone, so the answer holds once the signal is gone. Plan a trip to download each night ahead.")
                }
                .padding(24)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    Button {
                        start(nil)
                    } label: {
                        Text("Use my location").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    Button {
                        isAddingCamp = true
                    } label: {
                        Text("Add a camp").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .controlSize(.large)
                .padding(24)
                .background(.background)
            }
            .navigationDestination(isPresented: $isAddingCamp) {
                AddCampScreen { camp in
                    if let camp { start(camp) } else { isAddingCamp = false }
                }
            }
        }
    }
}

private struct Beat: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 36)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).foregroundStyle(.secondary)
            }
        }
    }
}
