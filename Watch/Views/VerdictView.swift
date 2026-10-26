// VerdictView.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

struct VerdictView: View {
    @Environment(ForecastModel.self) private var model

    var body: some View {
        TimelineView(.everyMinute) { context in
            if let night = model.night, let verdict = model.verdict {
                NavigationLink {
                    DetailView()
                } label: {
                    VerdictContent(
                        text: VerdictText(night: night, verdict: verdict, settings: model.settings, units: model.preferences.units),
                        now: context.date
                    )
                }
                .buttonStyle(.plain)
            } else if model.isRefreshing {
                ProgressView("Checking the sky")
            } else {
                ProblemView(message: model.problem ?? "No forecast yet.")
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink {
                    CampsView()
                } label: {
                    Image(systemName: "list.bullet")
                }
                .accessibilityLabel("Camps")
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
    }
}

private struct VerdictContent: View {
    let text: VerdictText
    let now: Date

    var body: some View {
        ScrollView {
            VStack(spacing: 4) {
                TentGlyph(flyOn: text.verdict.flyOn)
                    .frame(height: 52)
                    .foregroundStyle(text.verdict.flyOn ? Color.accentColor : .secondary)
                Text(text.period(at: now).uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(text.headline)
                    .font(.title2.bold())
                Text(text.reason)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                ForEach(text.notes, id: \.self) { note in
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                Text("\(text.night.location.name) · \(VerdictText.age(since: text.night.fetchedAt, at: now))")
                    .font(.caption2)
                    .foregroundStyle(ageColor)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Shows every check")
        }
    }

    private var ageColor: Color {
        switch VerdictText.staleness(since: text.night.fetchedAt, at: now) {
        case .fresh: .secondary
        case .aging: .orange
        case .stale: .red
        }
    }
}

private struct ProblemView: View {
    @Environment(ForecastModel.self) private var model
    let message: String

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Image(systemName: "cloud.sun")
                    .font(.title)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(message)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                Button("Try again") {
                    Task { await model.refresh() }
                }
            }
        }
    }
}
