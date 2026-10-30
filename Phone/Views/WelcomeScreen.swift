// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

struct WelcomeScreen: View {
    @Environment(ForecastModel.self) private var model
    let start: (CampLocation?) -> Void
    @State private var path: [Step] = []

    enum Step { case diary, begin, addCamp }

    var body: some View {
        NavigationStack(path: $path) {
            WelcomePage {
                TentGlyph(flyOn: true)
                    .frame(height: 96)
                    .foregroundStyle(Color.accentColor)
                    .frame(maxWidth: .infinity)
                Text("Rainfly")
                    .font(.largeTitle.bold())
                    .frame(maxWidth: .infinity)
                Beat(symbol: "tent", title: "Should the rainfly go on tonight?",
                     detail: "Rainfly reads the night's forecast for your campsite and answers with Rainfly on or Rainfly off, and the reason.")
                Beat(symbol: "checklist", title: "Seven checks",
                     detail: "Storms, rain, wind-driven rain, frost, dew, morning rain and cold. Any one of them puts the rainfly on. Tap a check to see why it matters.")
                Beat(symbol: "antenna.radiowaves.left.and.right.slash", title: "Ready offline",
                     detail: "Forecasts stay on your iPhone, so the answer holds once the signal is gone. Plan a trip to download each night ahead.")
            } buttons: {
                Button {
                    path.append(.diary)
                } label: {
                    Text("Continue").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .navigationDestination(for: Step.self) { step in
                switch step {
                case .diary: diary
                case .begin: begin
                case .addCamp:
                    AddCampScreen { camp in
                        if let camp { start(camp) } else { path.removeLast() }
                    }
                }
            }
        }
    }

    private var diary: some View {
        WelcomePage {
            Beat(symbol: "drop", title: "Keep a dew diary",
                 detail: "Dew is the hardest check to forecast, and it depends on your campsite. The dew diary tests Rainfly's dew forecast against your own mornings.")
            Beat(symbol: "sunrise", title: "One tap each morning",
                 detail: "Before you break camp, Rainfly reminds you and asks what you found on something left out overnight, such as a car windshield or a picnic table: dry, light dew, wet, frost or rain.")
            Beat(symbol: "slider.horizontal.3", title: "A setting tuned to you",
                 detail: "Rainfly counts the nights its dew forecast got right and wrong. After a few nights of both dry and wet mornings, it suggests a dew-point gap that suits where you camp.")
            Beat(symbol: "icloud.and.arrow.up", title: "Shared to improve the forecast",
                 detail: "Each night you answer is sent to Excelano to help improve the dew forecast, with the camp's position rounded to about 11 km and nothing about you. To keep the diary on this iPhone, turn off Share with Excelano in Settings.")
        } buttons: {
            if model.preferences.dewDiary {
                Button {
                    path.append(.begin)
                } label: {
                    Text("Continue").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button {
                    model.preferences.dewDiary = true
                    path.append(.begin)
                    Task { await DiaryReminder.requestPermission() }
                } label: {
                    Text("Turn on the dew diary").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Button {
                    path.append(.begin)
                } label: {
                    Text("Not now").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var begin: some View {
        WelcomePage {
            Beat(symbol: "location", title: "Where are you camping?",
                 detail: "Use your location to see tonight's answer for where you are, or add the camp you're heading to. You can add more camps and plan a trip from Camps at any time.")
        } buttons: {
            Button {
                start(nil)
            } label: {
                Text("Use my location").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            Button {
                path.append(.addCamp)
            } label: {
                Text("Add a camp").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct WelcomePage<Content: View, Buttons: View>: View {
    @ViewBuilder var content: Content
    @ViewBuilder var buttons: Buttons

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                content
            }
            .padding(24)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                buttons
            }
            .controlSize(.large)
            .padding(24)
            .background(.background)
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
