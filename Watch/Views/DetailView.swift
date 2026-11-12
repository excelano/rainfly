// DetailView.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

struct DetailView: View {
    @Environment(ForecastModel.self) private var model

    var body: some View {
        List {
            let now = AppClock.now
            if let night = model.night, let verdict = model.verdict, let phase = model.window?.phase(at: now) {
                let wholeNight = VerdictText(night: night, verdict: verdict, settings: model.settings, units: model.preferences.units)
                let text = phase == .overnight ? wholeNight.ahead(of: now) : wholeNight
                let window = text.window
                Section {
                    ForEach(text.checks, id: \.self) { trigger in
                        NavigationLink {
                            CheckDetail(trigger: trigger, text: text) { ChecksSettingsView() }
                        } label: {
                            CheckRow(trigger: trigger, text: text)
                        }
                    }
                }
                Section {
                    if let low = window.low {
                        LabeledContent("Night low", value: text.low(low))
                    }
                    if let spread = window.closestSpread {
                        LabeledContent("Closest dew-point gap", value: text.spread(spread))
                    }
                    if let chance = window.maxPrecipChance {
                        LabeledContent("Highest chance of rain before you pack up", value: text.percent(chance))
                    }
                }
            }
            Section {
                Button {
                    Task { await model.refresh() }
                } label: {
                    if model.isRefreshing {
                        ProgressView()
                    } else {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(model.isRefreshing)
                if let problem = model.problem {
                    Text(problem)
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
            Section {
                AttributionView(attribution: model.attribution)
            }
        }
        .navigationTitle(title)
    }
}

extension DetailView {
    private var title: String {
        guard let night = model.night, let verdict = model.verdict else { return "Tonight" }
        return VerdictText(night: night, verdict: verdict, settings: model.settings, units: model.preferences.units).period(at: .now)
    }
}
