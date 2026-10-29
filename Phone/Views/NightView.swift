// NightView.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

/// One night's verdict with every check under it, for tonight or a night of the trip, and
/// any `extra` section between the verdict and the checks.
struct NightView<Extra: View>: View {
    let text: VerdictText
    let now: Date
    let attribution: Attribution
    var problem: String?
    /// Names the night in place of "Tonight", for a later night of the trip.
    var period: String?
    @ViewBuilder var extra: Extra

    private var shownPeriod: String { period ?? text.period(at: now) }

    private var overnight: String {
        switch shownPeriod {
        case "Tonight": "Overnight tonight"
        case "This morning": "Overnight last night"
        default: "Overnight \(shownPeriod)"
        }
    }

    private var window: NightWindow { NightWindow(text.night, packByMinutes: text.settings.packByMinutes) }

    var body: some View {
        List {
            Section {
                VerdictHeader(text: text, period: shownPeriod)
            }
            .listRowBackground(Color.clear)
            if let problem {
                Section {
                    Label(problem, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }
            extra
            Section("Checks") {
                ForEach(text.checks, id: \.self) { trigger in
                    NavigationLink {
                        CheckDetail(trigger: trigger, text: text) { ChecksSettingsScreen() }
                    } label: {
                        CheckRow(trigger: trigger, text: text)
                    }
                }
            }
            Section(overnight) {
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
            Section {
                AttributionView(attribution: attribution, markHeight: 18)
            } footer: {
                Text("\(text.night.location.title) · \(VerdictText.age(since: text.night.fetchedAt, at: now))")
                    .foregroundStyle(VerdictText.staleness(since: text.night.fetchedAt, at: now).color)
            }
        }
    }
}

extension NightView where Extra == EmptyView {
    init(text: VerdictText, now: Date, attribution: Attribution, problem: String? = nil, period: String? = nil) {
        self.init(text: text, now: now, attribution: attribution, problem: problem, period: period) { EmptyView() }
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
