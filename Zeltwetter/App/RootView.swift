// RootView.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

/// Checks the cache, and the sky when the cache is old, whenever the app comes forward.
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ForecastModel.self) private var model

    var body: some View {
        NavigationStack {
            VerdictView()
                #if DEBUG
                .navigationDestination(isPresented: .constant(Demo.opens != nil)) {
                    if Demo.opens == "settings" { SettingsView() } else { DetailView() }
                }
                #endif
        }
        .task(id: scenePhase) {
            if scenePhase == .active {
                await model.refreshIfStale()
            }
        }
    }
}
