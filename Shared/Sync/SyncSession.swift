// SyncSession.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
import os
import WatchConnectivity

private let log = Logger(subsystem: "com.excelano.zeltwetter", category: "sync")

/// Carries the shared state and fetched trip nights between the phone and the watch. It only
/// moves bytes; `SyncRules` and the model decide what to keep. With no counterpart app
/// installed it sends nothing, and each app works alone.
@MainActor
final class SyncSession: NSObject, WCSessionDelegate {
    private let model: ForecastModel
    private let store: SettingsStore
    private let session = WCSession.default

    init(model: ForecastModel, store: SettingsStore = SettingsStore()) {
        self.model = model
        self.store = store
        super.init()
        guard WCSession.isSupported() else { return }
        model.sharedStateChanged = { [weak self] in self?.sendState() }
        model.nightFetched = { [weak self] night in self?.send(night) }
        session.delegate = self
        session.activate()
    }

    private var counterpartInstalled: Bool {
        guard session.activationState == .activated else { return false }
        #if os(iOS)
        return session.isPaired && session.isWatchAppInstalled
        #else
        return session.isCompanionAppInstalled
        #endif
    }

    /// Sends the state unless it is what was sent last, which every background launch would
    /// otherwise send again; `force` sends it anyway, for a counterpart that was reinstalled
    /// and has lost it.
    private func sendState(force: Bool = false) {
        guard counterpartInstalled else { return }
        let message = SyncMessage(state: model.sharedState, pressureWatch: model.preferences.pressureWatch)
        do {
            let data = try Self.encoder.encode(message)
            guard force || data != store.lastSentState else { return }
            try session.updateApplicationContext(["state": data])
            store.lastSentState = data
        } catch {
            log.error("Sending the state failed: \(error, privacy: .public)")
        }
    }

    /// Sorted keys, so the same state always encodes to the same bytes.
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    private func send(_ night: NightForecast) {
        guard counterpartInstalled, let data = try? JSONEncoder().encode(night) else { return }
        session.transferUserInfo(["night": data])
    }

    private func received(_ message: SyncMessage?) async {
        guard let message else { return }
        #if os(iOS)
        store.watchWatchesPressure = SyncRules.phoneStandsDown(
            watchAppInstalled: session.isWatchAppInstalled, watchPressureWatch: message.pressureWatch
        )
        #endif
        await model.apply(message.state)
    }

    private nonisolated static func message(in context: [String: Any]) -> SyncMessage? {
        (context["state"] as? Data).flatMap { try? JSONDecoder().decode(SyncMessage.self, from: $0) }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        if let error { log.error("Activation failed: \(error, privacy: .public)") }
        let message = Self.message(in: session.receivedApplicationContext)
        Task { @MainActor in
            await received(message)
            sendState()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        let message = Self.message(in: context)
        Task { @MainActor in await received(message) }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo["night"] as? Data,
              let night = try? JSONDecoder().decode(NightForecast.self, from: data)
        else {
            log.error("A transfer held no night")
            return
        }
        Task { @MainActor in model.receive(night) }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    /// A switch to another watch deactivates the session; activating again pairs with the new one.
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    /// Installing or removing the watch app, or pairing another watch, changes who warns.
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        let installed = session.isPaired && session.isWatchAppInstalled
        Task { @MainActor in
            if !installed { store.watchWatchesPressure = false }
            sendState(force: true)
        }
    }
    #else
    nonisolated func sessionCompanionAppInstalledDidChange(_ session: WCSession) {
        Task { @MainActor in sendState(force: true) }
    }
    #endif
}
