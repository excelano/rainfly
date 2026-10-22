// DetailView.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

struct DetailView: View {
    @Environment(ForecastModel.self) private var model

    var body: some View {
        List {
            if let night = model.night, let verdict = model.verdict, let window = model.window {
                let text = VerdictText(night: night, verdict: verdict, settings: model.settings)
                Section {
                    ForEach(Trigger.allCases, id: \.self) { trigger in
                        TriggerRow(trigger: trigger, firing: verdict.firing(trigger), text: text)
                    }
                }
                Section {
                    if let low = window.low {
                        LabeledContent("Night low", value: text.degrees(low))
                    }
                    if let spread = window.closestSpread {
                        LabeledContent("Closest spread", value: text.degreeSpan(spread))
                    }
                    if let chance = window.maxPrecipChance {
                        LabeledContent("Rain chance", value: text.percent(chance))
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
        .navigationTitle("Tonight")
    }
}

private struct TriggerRow: View {
    let trigger: Trigger
    let firing: Firing?
    let text: VerdictText

    var body: some View {
        HStack {
            Image(systemName: firing == nil ? "checkmark.circle" : "xmark.circle.fill")
                .foregroundStyle(firing == nil ? .green : .red)
            Text(VerdictText.name(trigger))
            Spacer()
            if let firing {
                Text(text.clock(firing.at))
                    .foregroundStyle(.secondary)
            }
        }
        .font(.footnote)
    }
}

/// The Apple Weather mark and the legal link WeatherKit requires. Offline, the mark falls
/// back to text.
private struct AttributionView: View {
    let attribution: Attribution

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            AsyncImage(url: attribution.markURL) { image in
                image.resizable().scaledToFit().frame(height: 14)
            } placeholder: {
                Text("\u{F8FF} Weather").font(.footnote)
            }
            Link("Data sources", destination: attribution.legalURL)
                .font(.footnote)
        }
    }
}
