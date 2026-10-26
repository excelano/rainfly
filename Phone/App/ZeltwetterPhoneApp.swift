// ZeltwetterPhoneApp.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

@main
struct ZeltwetterPhoneApp: App {
    @State private var model: ForecastModel
    private let sync: SyncSession?
    private let recorder: DiaryRecorder?

    init() {
        #if DEBUG
        if let scene = Demo.scene {
            let model = Demo.model(scene: scene)
            _model = State(initialValue: model)
            sync = nil
            recorder = Demo.opens == "diary" ? Self.demoRecorder(model) : nil
            return
        }
        #endif
        let model = ForecastModel.live()
        _model = State(initialValue: model)
        sync = SyncSession(model: model)
        recorder = DiaryRecorder(model: model)
    }

    #if DEBUG
    private static func demoRecorder(_ model: ForecastModel) -> DiaryRecorder {
        let store = Store<DewDiary>(url: FileManager.default.temporaryDirectory.appending(path: "demo-diary.json"))
        store.save(Demo.diary())
        return DiaryRecorder(model: model, store: store)
    }
    #endif

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(\.diaryRecorder, recorder)
        }
        .backgroundTask(.appRefresh(RefreshTiming.identifier)) { [model] in
            await PhoneRefreshScheduler.run(model, pressure: .live())
        }
    }
}
