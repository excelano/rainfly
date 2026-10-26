// VerdictScreen.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

/// The night that matters now, at the trip's camp or the phone's own position.
struct VerdictScreen: View {
    @Environment(ForecastModel.self) private var model
    #if DEBUG
    @Environment(\.dewRecorder) private var recorder
    #endif

    var body: some View {
        TimelineView(.everyMinute) { context in
            if let night = model.night, let verdict = model.verdict {
                NightView(
                    text: VerdictText(night: night, verdict: verdict, settings: model.settings, units: model.preferences.units),
                    now: context.date,
                    attribution: model.attribution,
                    problem: model.problem
                )
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
                }
            }
        }
        #if DEBUG
        .safeAreaInset(edge: .bottom) {
            TimelineView(.everyMinute) { context in
                if let recorder, let night = recorder.log.awaitingObservation(now: context.date, campName: model.camps.campName) {
                    DewCheckCard(recorder: recorder, night: night)
                }
            }
        }
        #endif
        .refreshable { await model.refresh() }
        .navigationTitle(model.campName)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink {
                    CampsScreen()
                } label: {
                    Label("Camps", systemImage: "list.bullet")
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
    }
}
