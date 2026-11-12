// OvernightView.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

/// The night after 22:00: the latest verdict and what has changed since then, the weather
/// right now, the hours until sunrise, and any `diary` section once the morning question opens.
struct OvernightView<Diary: View>: View {
    let overnight: OvernightText
    let current: CurrentConditions?
    let pressure: String?
    let now: Date
    let attribution: Attribution
    var problem: String?
    @ViewBuilder var diary: Diary

    private var text: VerdictText { overnight.text }

    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    Text(overnight.caption.uppercased())
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(overnight.headline)
                        .font(.largeTitle.bold())
                    Text(overnight.reason)
                        .font(.title3)
                        .fontWeight(overnight.change != nil ? .semibold : .regular)
                    if let note = overnight.note {
                        Text(note)
                            .foregroundStyle(.secondary)
                    }
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
                }
            }
            if current != nil || pressure != nil {
                Section {
                    if let current {
                        let now = overnight.now(current)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(now.title).font(.headline)
                            Text(now.detail).font(.footnote).foregroundStyle(.secondary)
                        }
                        LabeledContent("Air", value: text.temperature(current.tempC))
                        LabeledContent("Dew point", value: text.temperature(current.dewPointC))
                        LabeledContent("Clouds · wind", value: "\(text.percent(current.cloudCover)) · \(text.speed(current.windMS))")
                    }
                    if let pressure {
                        LabeledContent("Air pressure", value: pressure)
                    }
                } header: {
                    Text("Right now")
                } footer: {
                    Text(footer)
                }
            }
            diary
            let hours = overnight.hoursAhead
            if !hours.isEmpty {
                Section {
                    Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                        GridRow {
                            Text("")
                            ForEach(hours, id: \.date) { Text(overnight.hourLabel($0)).fontWeight(.semibold) }
                        }
                        GridRow {
                            Text("Gap").foregroundStyle(.secondary).gridColumnAlignment(.leading)
                            ForEach(hours, id: \.date) { Text(text.spread($0.spreadC)) }
                        }
                        GridRow {
                            Text("Rain").foregroundStyle(.secondary)
                            ForEach(hours, id: \.date) { hour in
                                Text(text.percent(hour.precipChance))
                                    .fontWeight(hour.precipChance >= text.settings.rainChance ? .bold : .regular)
                            }
                        }
                    }
                    .font(.footnote.monospacedDigit())
                    .frame(maxWidth: .infinity)
                } header: {
                    Text("Rest of the night")
                } footer: {
                    Text("Gap is how close the air is to its dew point. The closer it is, the more likely dew is.")
                }
            }
            Section("Checks") {
                ForEach(overnight.ahead.checks, id: \.self) { trigger in
                    NavigationLink {
                        CheckDetail(trigger: trigger, text: overnight.ahead) { ChecksSettingsScreen() }
                    } label: {
                        CheckRow(trigger: trigger, text: overnight.ahead)
                    }
                }
            }
            Section {
                AttributionView(attribution: attribution, markHeight: 18)
            } footer: {
                Text("\(text.night.location.title) · \(VerdictText.age(since: text.night.fetchedAt, at: now))")
            }
        }
    }

    private var footer: String {
        var parts: [String] = []
        if current != nil { parts.append("Air, clouds and wind are Apple Weather's best guess for this spot.") }
        else { parts.append("The weather right now needs a signal.") }
        if pressure != nil { parts.append("The air pressure comes from this \(UIDevice.current.model)'s own sensor.") }
        return parts.joined(separator: " ")
    }
}
