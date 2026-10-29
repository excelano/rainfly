// RootView.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

/// Checks the cache, and the sky when the cache is old, whenever the app comes forward,
/// and books the next background refresh when it goes. With the always-on display the app
/// stays active when the wrist drops, so the display dimming counts as going and brightening
/// as coming forward.
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
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
            case .background:
                RefreshScheduler.schedule(model)
            default:
                break
            }
        }
        .onChange(of: model.verdict?.flyOn, initial: true) {
            if model.verdict?.flyOn == false, model.preferences.pressureWatch, !isDemo {
                Task { await PressureWatch.requestPermission() }
            }
        }
        .onChange(of: isLuminanceReduced) {
            if isLuminanceReduced {
                RefreshScheduler.schedule(model)
            } else {
                Task { await model.refreshIfStale() }
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
