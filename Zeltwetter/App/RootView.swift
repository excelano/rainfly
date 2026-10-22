// RootView.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

/// Checks the cache, and the sky when the cache is old, whenever the app comes forward,
/// and books the next background refresh when it goes.
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ForecastModel.self) private var model

    var body: some View {
        NavigationStack {
            VerdictView()
                #if DEBUG
                .navigationDestination(isPresented: .constant(Demo.opens != nil)) {
                    switch Demo.opens {
                    case "settings": SettingsView()
                    case "camps": CampsView()
                    default: DetailView()
                    }
                }
                #endif
        }
        .task(id: scenePhase) {
            switch scenePhase {
            case .active:
                await model.refreshIfStale()
                if model.preferences.pressureWatch, !isDemo { await PressureWatch.requestPermission() }
            case .background:
                RefreshScheduler.schedule(model)
            default:
                break
            }
        }
    }

    /// Demo screenshots stay free of permission prompts.
    private var isDemo: Bool {
        #if DEBUG
        Demo.scene != nil
        #else
        false
        #endif
    }
}
