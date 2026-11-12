// VerdictView.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

struct VerdictView: View {
    @Environment(ForecastModel.self) private var model

    var body: some View {
        TimelineView(.everyMinute) { context in
            let now = Self.now(context.date)
            if let night = model.night, let verdict = model.verdict {
                let text = VerdictText(night: night, verdict: verdict, settings: model.settings, units: model.preferences.units)
                NavigationLink {
                    DetailView()
                } label: {
                    VerdictContent(lines: lines(text, at: now), text: text, now: now)
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
                    Image(systemName: "tent")
                }
                .accessibilityLabel("Camps")
                .tint(nil)
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
                .tint(nil)
            }
        }
    }
}

/// What the main screen says, for the part of the night it is in.
struct VerdictLines {
    let flyOn: Bool
    let caption: String
    let headline: String
    let reason: String
    var warning: String?
    var notes: [String] = []
    var muted = false
}

extension VerdictView {
    private func lines(_ text: VerdictText, at now: Date) -> VerdictLines {
        let night = text.night
        switch NightWindow(night, packByMinutes: text.settings.packByMinutes).phase(at: now) {
        case .evening:
            return VerdictLines(
                flyOn: text.verdict.flyOn, caption: text.periodLabel(at: now), headline: text.headline, reason: text.reason,
                warning: text.beforeTonightText(at: now), notes: text.notes(at: now)
            )
        case .overnight:
            let overnight = OvernightText(
                text: text, decided: model.decided ?? night, decidedSettings: model.decidedSettings, now: now, current: model.current
            )
            let current = model.current.map { overnight.now($0).title }
            return VerdictLines(
                flyOn: overnight.flyOn, caption: overnight.caption, headline: overnight.headline, reason: overnight.reason,
                notes: [overnight.note, current.map { "Right now: \($0.lowercased())" }].compactMap { $0 }
            )
        case .morning:
            let morning = MorningText(
                decided: model.decided ?? night, beforeMorning: model.beforeMorning, latest: night,
                settings: text.settings, decidedSettings: model.decidedSettings, units: text.units, alerted: model.wasAlerted
            )
            return VerdictLines(
                flyOn: morning.packing != .dryNight, caption: morning.caption, headline: morning.headline, reason: morning.reason,
                warning: morning.rainAhead(at: now), notes: [morning.advice, morning.madeACall ? morning.lastNightTitle : nil].compactMap { $0 },
                muted: morning.packing == .dryToPack
            )
        }
    }

    /// The device's time, or the one a Debug demo sets.
    private static func now(_ date: Date) -> Date {
        #if DEBUG
        Demo.now ?? date
        #else
        date
        #endif
    }
}

private struct VerdictContent: View {
    let lines: VerdictLines
    let text: VerdictText
    let now: Date

    var body: some View {
        ScrollView {
            VStack(spacing: 4) {
                TentGlyph(flyOn: lines.flyOn)
                    .frame(height: 52)
                    .foregroundStyle(lines.flyOn && !lines.muted ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                Text(lines.caption.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Text(lines.headline)
                    .font(.title2.bold())
                Text(lines.reason)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                if let warning = lines.warning {
                    Text(warning)
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                }
                ForEach(lines.notes, id: \.self) { note in
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                Text("\(text.night.location.title) · \(VerdictText.age(since: text.night.fetchedAt, at: now))")
                    .font(.caption2)
                    .foregroundStyle(VerdictText.staleness(since: text.night.fetchedAt, at: now).color)
                    .padding(.top, 4)
                Label("All checks", systemImage: "chevron.right")
                    .labelStyle(TrailingIcon())
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Shows every check")
        }
    }
}

private struct TrailingIcon: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.title
            configuration.icon.imageScale(.small)
        }
    }
}

private struct ProblemView: View {
    @Environment(ForecastModel.self) private var model
    let message: String
    @State private var isAddingCamp = false

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
                Button("Add a camp") { isAddingCamp = true }
            }
        }
        .sheet(isPresented: $isAddingCamp) {
            NavigationStack {
                AddCampView { camp in
                    isAddingCamp = false
                    if let camp { Task { await model.show(camp.name) } }
                }
            }
        }
    }
}
