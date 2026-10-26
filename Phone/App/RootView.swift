// RootView.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

/// Checks the cache, and the sky when the cache is old, whenever the app comes forward,
/// and books the next background refresh when it goes.
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ForecastModel.self) private var model
    @Environment(\.diaryRecorder) private var recorder

    var body: some View {
        NavigationStack {
            VerdictScreen()
                #if DEBUG
                .navigationDestination(isPresented: .constant(["camps", "settings", "diary"].contains(Demo.opens))) {
                    switch Demo.opens {
                    case "settings": SettingsScreen()
                    case "diary": if let recorder { DiaryScreen(recorder: recorder) }
                    default: CampsScreen()
                    }
                }
                #endif
        }
        .task(id: scenePhase) {
            switch scenePhase {
            case .active:
                await model.refreshIfStale()
                if !isDemo { await recorder?.fillHistory() }
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
