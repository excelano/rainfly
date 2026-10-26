// RefreshLog.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import CoreMotion
import Foundation

/// A record of each background refresh, kept in Debug builds only, for checking from a Mac how often the
/// system woke the app and what the pressure watch made of each wake. It lives in the App
/// Group as refreshlog.json, keeps the newest `kept` entries, and is pulled with devicectl.
struct RefreshLog: Codable {
    struct Entry: Codable {
        let date: Date
        let pressureWatch: Bool
        let motion: String
        let barometer: Bool
        let pressure: PressureWatch.Outcome?
        let forecastAge: TimeInterval?
    }

    private(set) var entries: [Entry] = []
    static let kept = 400

    /// Does nothing outside Debug builds.
    @MainActor
    static func record(pressureWatch: Bool, pressure: PressureWatch.Outcome?, fetchedAt: Date?, now: Date = .now) {
        #if DEBUG
        let store = Store<RefreshLog>(name: "refreshlog")
        var log = store.load() ?? RefreshLog()
        let motion = switch CMAltimeter.authorizationStatus() {
        case .authorized: "authorized"
        case .denied: "denied"
        case .restricted: "restricted"
        case .notDetermined: "notDetermined"
        @unknown default: "unknown"
        }
        log.entries.append(Entry(
            date: now, pressureWatch: pressureWatch, motion: motion,
            barometer: CMAltimeter.isRelativeAltitudeAvailable(), pressure: pressure,
            forecastAge: fetchedAt.map { now.timeIntervalSince($0) }
        ))
        log.entries = Array(log.entries.suffix(kept))
        store.save(log)
        #endif
    }
}
