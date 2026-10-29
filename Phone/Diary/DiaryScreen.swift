// DiaryScreen.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

/// The dew diary: how the dew forecast has done on the nights answered, a better dew spread
/// when the nights show one, and every night with what was found.
struct DiaryScreen: View {
    @Environment(ForecastModel.self) private var model
    let recorder: DiaryRecorder
    @State private var answering: DiaryNight?

    var body: some View {
        let settings = model.settings
        let units = model.preferences.units
        let tally = recorder.diary.tally(settings: settings)
        List {
            if tally.judged + tally.lightDew > 0 {
                Section {
                    LabeledContent("Caught", value: "\(tally.caught)")
                    LabeledContent("Clear", value: "\(tally.clear)")
                    LabeledContent("Missed", value: "\(tally.missed)")
                    LabeledContent("False alarms", value: "\(tally.falseAlarms)")
                    LabeledContent("Light dew", value: tally.lightDew == 0 ? "0" : "\(tally.lightDew), \(tally.lightDewFlagged) flagged")
                } header: {
                    Text("How the forecast did")
                } footer: {
                    Text("Caught and clear are nights the dew check called right. Light dew is marginal, so either call counts as fine; rain nights are left out.")
                }
            }
            if let suggestion = recorder.diary.suggestedDewSpread(settings: settings, units: units) {
                SuggestionSection(suggestion: suggestion, units: units) {
                    model.settings.dewSpreadC = suggestion.suggested.spreadC
                }
            }
            if model.preferences.dewDiary {
                SharingSection(recorder: recorder)
            }
            Section {
                if recorder.diary.nights.isEmpty {
                    Text("No nights yet. A night appears here once the diary has kept a forecast for it.")
                        .foregroundStyle(.secondary)
                }
                ForEach(recorder.diary.nights.reversed(), id: \.id) { night in
                    Button {
                        answering = night
                    } label: {
                        NightRow(night: night, judgement: night.judge(settings: settings), units: units)
                    }
                    .tint(.primary)
                }
                .onDelete { offsets in
                    let shown = Array(recorder.diary.nights.reversed())
                    for night in offsets.map({ shown[$0] }) { recorder.remove(night) }
                }
            } header: {
                Text("Nights")
            }
        }
        .navigationTitle("Dew diary")
        .sheet(item: $answering) { night in
            NavigationStack {
                Form {
                    Section {
                        DiaryAnswerRows(recorder: recorder, night: night) { answering = nil }
                    } footer: {
                        Text("What you found on the morning after \(NightRow.title(night)).")
                    }
                }
                .navigationTitle("What you found")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { answering = nil }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }
}

private struct SuggestionSection: View {
    let suggestion: SpreadSuggestion
    let units: DisplayUnits
    let apply: () -> Void

    var body: some View {
        let quantity = Quantity.dewSpread(units)
        Section {
            Text("A dew-point gap of \(quantity.text(suggestion.suggested.spreadC)) would have caught \(suggestion.suggested.caught) of \(suggestion.wetNights) wet nights with \(Self.alarms(suggestion.suggested.falseAlarms)). The current \(quantity.text(suggestion.current.spreadC)) catches \(suggestion.current.caught) with \(Self.alarms(suggestion.current.falseAlarms)).")
            Button("Apply \(quantity.text(suggestion.suggested.spreadC))", action: apply)
        } header: {
            Text("Suggested setting")
        } footer: {
            Text("From the nights checked under open sky. A yard or a driveway usually gets less dew than a campsite in a valley or by water, so a setting tuned at home may still miss dew at camp.")
        }
    }

    private static func alarms(_ count: Int) -> String {
        switch count {
        case 0: "no false alarms"
        case 1: "1 false alarm"
        default: "\(count) false alarms"
        }
    }
}

private struct NightRow: View {
    let night: DiaryNight
    let judgement: DiaryJudgement?
    let units: DisplayUnits

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(Self.title(night)) · \(CampLocation.title(night.campName))")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(found)
            Text(forecast)
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let verdict {
                Text(verdict)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(judgementColor)
            }
        }
        .accessibilityElement(children: .combine)
    }

    static func title(_ night: DiaryNight) -> String {
        night.date.start(in: .current).formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    private var found: String {
        guard let observation = night.observation else {
            let sunrise = night.forecasts.last?.sunrise ?? .distantPast
            return Date.now < sunrise ? "Waiting for the morning" : "Not answered"
        }
        let place = observation.openSky ? "" : ", under trees"
        return observation.kind == .notChecked ? "Not checked" : "Found: \(observation.kind.title.lowercased())\(place)"
    }

    private var forecast: String {
        guard let judgement else { return "No forecast kept" }
        let spread = judgement.closestSpread.map { ", closest gap \(Quantity.dewSpread(units).format(units.temperatureSpan($0)))" } ?? ""
        let call = judgement.firing.map { "\($0.trigger == .frost ? "frost" : "dew") by \(Self.clock($0.at, in: night))" } ?? "dry"
        return "Forecast: \(call)\(spread)"
    }

    private var verdict: String? {
        switch judgement?.outcome {
        case .caught?: "Caught"
        case .clear?: "Clear"
        case .missed?: "Missed · \(cause)"
        case .falseAlarm?: "False alarm · \(cause)"
        case nil: nil
        }
    }

    private var cause: String {
        switch judgement?.cause {
        case .forecast?: "the forecast missed"
        case .settings?: "the settings missed"
        case nil: "cause not known yet"
        }
    }

    private var judgementColor: Color {
        switch judgement?.outcome {
        case .missed?, .falseAlarm?: .orange
        default: .green
        }
    }

    private static func clock(_ date: Date, in night: DiaryNight) -> String {
        var style = Date.FormatStyle().hour().minute()
        style.timeZone = night.forecasts.first?.location.timeZone ?? .current
        return date.formatted(style)
    }
}

extension DiaryNight: Identifiable {
    var id: String { "\(campName)|\(date.year)-\(date.month)-\(date.day)" }
}

/// The switch for sharing the diary. Turning it on the first time makes the diary ID, and
/// sends whatever is answered.
struct ShareToggle: View {
    @Environment(ForecastModel.self) private var model
    let recorder: DiaryRecorder

    var body: some View {
        @Bindable var model = model
        Toggle("Share with Excelano", isOn: $model.preferences.shareDiary)
            .onChange(of: model.preferences.shareDiary) {
                guard model.preferences.shareDiary else { return }
                if model.preferences.diaryID == nil { model.preferences.diaryID = UUID() }
                Task { await recorder.share() }
            }
    }
}

/// Sharing the diary with Excelano: the switch, what is sent, how the last send went, and
/// the ways to stop being linked or to take back what was sent.
struct SharingSection: View {
    @Environment(ForecastModel.self) private var model
    let recorder: DiaryRecorder
    @State private var isConfirmingDelete = false

    var body: some View {
        @Bindable var model = model
        Section {
            ShareToggle(recorder: recorder)
            if let problem = recorder.shareProblem {
                Label(problem, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            } else if recorder.isSharing {
                ProgressView("Sending")
            } else if let last = recorder.lastShared {
                LabeledContent("Last sent", value: last.formatted(date: .abbreviated, time: .shortened))
            }
            if let id = model.preferences.diaryID {
                if model.preferences.shareDiary {
                    LabeledContent("Diary ID") {
                        Text(id.uuidString.lowercased())
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }
                }
                Button("New diary ID") {
                    model.preferences.diaryID = UUID()
                }
            }
            if recorder.sharedCount > 0 {
                Button("Delete shared nights", role: .destructive) {
                    isConfirmingDelete = true
                }
            }
        } header: {
            Text("Sharing")
        } footer: {
            Text("Shared nights help improve the dew check. Each answered night is sent to Excelano's database in Apple's iCloud with what you found, the night's forecast and its history, your thresholds, the camp's position rounded to about 11 km, and a random diary ID that tells one site's nights from another's. Camp names, exact positions and anything about you or this iPhone are never sent. A new diary ID keeps later nights from being linked to earlier ones. Sharing needs iCloud.")
        }
        .confirmationDialog("Delete the \(recorder.sharedCount == 1 ? "night" : "\(recorder.sharedCount) nights") this iPhone shared?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete shared nights", role: .destructive) {
                Task { await recorder.deleteShared() }
            }
        } message: {
            Text("The diary on this iPhone stays as it is.")
        }
    }
}
