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
            if let night = model.night, let verdict = model.verdict {
                NightView(
                    text: VerdictText(night: night, verdict: verdict, settings: model.settings, units: model.preferences.units),
                    now: context.date,
                    attribution: model.attribution,
                    problem: model.problem
                ) {
                    if model.preferences.dewDiary, let recorder,
                       let night = recorder.diary.awaitingObservation(now: context.date, campName: model.camps.campName) {
                        MorningCheckSection(recorder: recorder, night: night)
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
}
