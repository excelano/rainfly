// MorningView.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

/// The morning after a night, until noon: what Rainfly expected last night, whether that was
/// right, and a way to look at tonight early.
struct MorningView<Diary: View>: View {
    let morning: MorningText
    let now: Date
    let attribution: Attribution
    var problem: String?
    @ViewBuilder var diary: Diary

    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    TentGlyph(flyOn: morning.flyOn)
                        .frame(height: 96)
                        .foregroundStyle(morning.flyOn ? Color.accentColor : .secondary)
                    Text(morning.caption.uppercased())
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(morning.headline)
                        .font(.largeTitle.bold())
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .accessibilityElement(children: .combine)
            }
            .listRowBackground(Color.clear)
            if let problem {
                Section {
                    Label(problem, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }
            diary
            Section {
                NavigationLink {
                    UpcomingNightView()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tonight's forecast")
                            .foregroundStyle(Color.accentColor)
                        Text("Shown here from \(morning.handoverTime)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                AttributionView(attribution: attribution, markHeight: 18)
            } footer: {
                Text("\(morning.text.night.location.title) · \(VerdictText.age(since: morning.text.night.fetchedAt, at: now))")
                    .foregroundStyle(VerdictText.staleness(since: morning.text.night.fetchedAt, at: now).color)
            }
        }
    }
}

/// Tonight's forecast before noon, fetched if it isn't on the device yet.
private struct UpcomingNightView: View {
    @Environment(ForecastModel.self) private var model
    @State private var night: NightForecast?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let night {
                NightView(
                    text: VerdictText(night: night, settings: model.settings, units: model.preferences.units),
                    now: AppClock.now, attribution: model.attribution, period: "Tonight"
                )
            } else if isLoading {
                ProgressView("Checking the sky")
            } else {
                ContentUnavailableView("No forecast for tonight yet", systemImage: "cloud.sun", description: Text("Rainfly needs a signal to get tonight's forecast."))
            }
        }
        .navigationTitle("Tonight")
        .task {
            night = await model.upcoming()
            isLoading = false
        }
    }
}
