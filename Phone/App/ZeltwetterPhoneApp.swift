// ZeltwetterPhoneApp.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

@main
struct ZeltwetterPhoneApp: App {
    @State private var model: ForecastModel

    init() {
        #if DEBUG
        if let scene = Demo.scene {
            _model = State(initialValue: Demo.model(scene: scene))
            return
        }
        #endif
        _model = State(initialValue: ForecastModel.live())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
        }
    }
}
