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
    @AppStorage("welcomed") private var welcomed = false

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
                guard welcomed || isDemo else { return }
                await model.refreshIfStale()
                if !isDemo {
                    await recorder?.fillHistory()
                    await recorder?.share()
                }
            case .background:
                PhoneRefreshScheduler.schedule(model)
            default:
                break
            }
        }
        .onChange(of: model.verdict?.flyOn, initial: true) {
            if model.verdict?.flyOn == false, model.preferences.pressureWatch, !isDemo {
                Task { await PressureWatch.requestPermission() }
            }
        }
        .fullScreenCover(isPresented: .constant(!welcomed && !isDemo)) {
            WelcomeScreen { camp in
                welcomed = true
                Task {
                    if let camp { await model.show(camp.name) } else { await model.refreshIfStale() }
                }
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
