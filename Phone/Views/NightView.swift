// NightView.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

/// One night's verdict with every check under it, for tonight or a night of the trip.
struct NightView: View {
    let text: VerdictText
    let now: Date
    let attribution: Attribution
    var problem: String?
    /// Names the night in place of "Tonight", for a later night of the trip.
    var period: String?

    private var window: NightWindow { NightWindow(text.night, packByMinutes: text.settings.packByMinutes) }

    var body: some View {
        List {
            Section {
                VerdictHeader(text: text, period: period ?? text.period(at: now))
            }
            .listRowBackground(Color.clear)
            if let problem {
                Section {
                    Label(problem, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }
            Section("Checks") {
                ForEach(Trigger.allCases, id: \.self) { trigger in
                    TriggerRow(trigger: trigger, firing: text.verdict.firing(trigger), text: text)
                }
            }
            Section("The night") {
                if let low = window.low {
                    LabeledContent("Night low", value: text.degrees(low))
                }
                if let spread = window.closestSpread {
                    LabeledContent("Closest dew-point spread", value: text.degreeSpan(spread))
                }
                if let chance = window.maxPrecipChance {
                    LabeledContent("Highest rain chance", value: text.percent(chance))
                }
            }
            Section {
                AttributionView(attribution: attribution, markHeight: 18)
            } footer: {
                Text("\(text.night.location.name) · \(VerdictText.age(since: text.night.fetchedAt, at: now))")
                    .foregroundStyle(VerdictText.staleness(since: text.night.fetchedAt, at: now).color)
            }
        }
    }
}

private struct VerdictHeader: View {
    let text: VerdictText
    let period: String

    var body: some View {
        VStack(spacing: 8) {
            TentGlyph(flyOn: text.verdict.flyOn)
                .frame(height: 112)
                .foregroundStyle(text.verdict.flyOn ? Color.accentColor : .secondary)
            Text(period.uppercased())
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(text.headline)
                .font(.largeTitle.bold())
            Text(text.reason)
                .font(.title3)
            ForEach(text.notes, id: \.self) { note in
                Text(note)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}

private struct TriggerRow: View {
    let trigger: Trigger
    let firing: Firing?
    let text: VerdictText

    var body: some View {
        LabeledContent {
            if let firing {
                Text(text.clock(firing.at))
            }
        } label: {
            Label {
                Text(VerdictText.name(trigger))
            } icon: {
                Image(systemName: firing == nil ? "checkmark.circle" : "xmark.circle.fill")
                    .foregroundStyle(firing == nil ? .green : .red)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(VerdictText.name(trigger))
        .accessibilityValue(firing.map { "Expected at \(text.clock($0.at))" } ?? "Clear")
    }
}
