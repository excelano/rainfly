// ZeltwetterPhoneApp.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

@main
struct ZeltwetterPhoneApp: App {
    @State private var model: ForecastModel
    private let sync: SyncSession?

    init() {
        #if DEBUG
        if let scene = Demo.scene {
            _model = State(initialValue: Demo.model(scene: scene))
            sync = nil
            return
        }
        #endif
        let model = ForecastModel.live()
        _model = State(initialValue: model)
        sync = SyncSession(model: model)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
        }
        .backgroundTask(.appRefresh(RefreshTiming.identifier)) { [model] in
            await PhoneRefreshScheduler.run(model, pressure: .live())
        }
    }
}
