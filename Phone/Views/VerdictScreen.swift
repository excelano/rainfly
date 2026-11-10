// VerdictScreen.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

/// The night that matters now, at the trip's camp or the phone's own position.
struct VerdictScreen: View {
    @Environment(ForecastModel.self) private var model
    @Environment(\.diaryRecorder) private var recorder
    @State private var isAddingCamp = false

    var body: some View {
        TimelineView(.everyMinute) { context in
            let now = Self.now(context.date)
            if let night = model.night, let verdict = model.verdict, let window = model.window {
                let text = VerdictText(night: night, verdict: verdict, settings: model.settings, units: model.preferences.units)
                switch window.phase(at: now) {
                case .evening:
                    NightView(text: text, now: now, attribution: model.attribution, problem: model.problem) {
                        if model.preferences.dewDiary, let recorder,
                           let night = recorder.diary.awaitingObservation(now: now, campName: model.camps.campName) {
                            MorningCheckSection(recorder: recorder, night: night)
                        }
                    }
                case .overnight:
                    OvernightView(
                        overnight: OvernightText(text: text, decided: model.decided ?? night, decidedSettings: model.decidedSettings),
                        current: model.current, pressure: pressure, now: now,
                        attribution: model.attribution, problem: model.problem
                    )
                case .morning:
                    MorningView(
                        morning: MorningText(
                            decided: model.decided ?? night, beforeMorning: model.beforeMorning, latest: night,
                            settings: model.settings, decidedSettings: model.decidedSettings, units: model.preferences.units,
                            alerted: model.wasAlerted
                        ),
                        now: now, attribution: model.attribution, problem: model.problem
                    ) {
                        if model.preferences.dewDiary, let recorder,
                           let diaryNight = recorder.diary.nights.last(where: { $0.campName == model.campName && $0.date == model.date }) {
                            MorningDiarySection(recorder: recorder, night: diaryNight)
                        }
                    }
                }
            } else if model.isRefreshing {
                ProgressView("Checking the sky")
            } else {
                ContentUnavailableView {
                    Label("No forecast", systemImage: "cloud.sun")
                } description: {
                    Text(model.problem ?? "No forecast yet.")
                } actions: {
                    Button("Try again") {
                        Task { await model.refresh() }
                    }
                    Button("Add a camp") { isAddingCamp = true }
                }
            }
        }
        .refreshable { await model.refresh() }
        .overnightStyle(isOvernight: model.window?.phase(at: AppClock.now) == .overnight, red: model.preferences.redTint)
        .navigationTitle(CampLocation.title(model.campName))
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink {
                    CampsScreen()
                } label: {
                    Label("Camps", systemImage: "tent")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsScreen()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .sheet(isPresented: $isAddingCamp) {
            NavigationStack {
                AddCampScreen { camp in
                    isAddingCamp = false
                    if let camp { Task { await model.show(camp.name) } }
                }
            }
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

    /// The pressure's trend from the overnight readings, when they cover an hour or more.
    private var pressure: String? {
        guard model.preferences.pressureWatch else { return nil }
        return PressureWatch.live().store.load()?.trend.map(OvernightText.pressure)
    }
}
