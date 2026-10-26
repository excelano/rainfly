// SyncedState.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// What the phone and the watch keep the same: the camps and trip, the thresholds and the
/// units. Here, its forecasts, the pressure log and the pressure toggle belong to each device.
struct SyncedState: Codable, Equatable, Sendable {
    var camps: Camps
    var settings: Settings
    var units: DisplayUnits
    /// When this state was last changed on either device.
    var modifiedAt: Date
}

/// The application context one device sends the other.
struct SyncMessage: Codable, Equatable, Sendable {
    let state: SyncedState
    /// The sender's own pressure toggle, read by the phone so only one device warns.
    let pressureWatch: Bool
}

/// The choices sync makes, kept apart from WatchConnectivity so they can be tested.
enum SyncRules {
    /// The received state replaces the local one only when it was changed later; the whole
    /// state goes, so edits made on both devices while apart keep only the newer side's.
    static func adopts(_ received: SyncedState, over local: SyncedState) -> Bool {
        received.modifiedAt > local.modifiedAt
    }

    /// Here is each device's own position, so its nights stay where they were fetched.
    static func sends(_ night: NightForecast) -> Bool {
        night.location.name != CampLocation.hereName
    }

    /// A night from the other device is kept unless a newer fetch of it is already here.
    static func keeps(_ received: NightForecast, over cached: NightForecast?) -> Bool {
        sends(received) && (cached.map { received.fetchedAt > $0.fetchedAt } ?? true)
    }

    /// The phone stays quiet while the watch is watching: iOS mirrors a locked phone's
    /// notifications to the wrist, so two warners would tap twice for one fall.
    static func phoneStandsDown(watchAppInstalled: Bool, watchPressureWatch: Bool) -> Bool {
        watchAppInstalled && watchPressureWatch
    }
}
