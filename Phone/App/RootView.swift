// RootView.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

/// Checks the cache, and the sky when the cache is old, whenever the app comes forward,
/// and books the next background refresh when it goes.
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ForecastModel.self) private var model
    #if DEBUG
    @Environment(\.dewRecorder) private var recorder
    #endif

    var body: some View {
        NavigationStack {
            VerdictScreen()
                #if DEBUG
                .navigationDestination(isPresented: .constant(Demo.opens == "camps" || Demo.opens == "settings")) {
                    if Demo.opens == "settings" { SettingsScreen() } else { CampsScreen() }
                }
                #endif
        }
        .task(id: scenePhase) {
            switch scenePhase {
            case .active:
                await model.refreshIfStale()
                #if DEBUG
                await recorder?.fillActuals()
                #endif
                if model.preferences.pressureWatch, !isDemo { await PressureWatch.requestPermission() }
            case .background:
                PhoneRefreshScheduler.schedule(model)
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
