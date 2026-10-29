// DetailView.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

struct DetailView: View {
    @Environment(ForecastModel.self) private var model

    var body: some View {
        List {
            if let night = model.night, let verdict = model.verdict, let window = model.window {
                let text = VerdictText(night: night, verdict: verdict, settings: model.settings, units: model.preferences.units)
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
                        LabeledContent("Night low", value: text.degrees(low))
                    }
                    if let spread = window.closestSpread {
                        LabeledContent("Closest dew-point gap", value: text.degreeSpan(spread))
                    }
                    if let chance = window.maxPrecipChance {
                        LabeledContent("Highest rain chance", value: text.percent(chance))
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
