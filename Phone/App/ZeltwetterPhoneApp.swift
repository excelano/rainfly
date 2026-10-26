// ZeltwetterPhoneApp.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

@main
struct ZeltwetterPhoneApp: App {
    @State private var model: ForecastModel
    private let sync: SyncSession?
    #if DEBUG
    private let recorder: DewRecorder?
    #endif

    init() {
        #if DEBUG
        if let scene = Demo.scene {
            _model = State(initialValue: Demo.model(scene: scene))
            sync = nil
            recorder = nil
            return
        }
        #endif
        let model = ForecastModel.live()
        _model = State(initialValue: model)
        sync = SyncSession(model: model)
        #if DEBUG
        recorder = DewRecorder(model: model)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                #if DEBUG
                .environment(\.dewRecorder, recorder)
                #endif
        }
        .backgroundTask(.appRefresh(RefreshTiming.identifier)) { [model] in
            await PhoneRefreshScheduler.run(model, pressure: .live())
        }
    }
}
