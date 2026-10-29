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
    var changedAt: [String: Date]
}

/// The application context one device sends the other.
struct SyncMessage: Codable, Equatable, Sendable {
    let state: SyncedState
    /// The sender's own pressure toggle, read by the phone so only one device warns.
    let pressureWatch: Bool
}

/// The choices sync makes, kept apart from WatchConnectivity so they can be tested.
enum SyncRules {
    static func items(_ state: SyncedState) -> [String: Data] {
        var items: [String: Data] = [:]
        for camp in state.camps.saved { items["camp/" + camp.name] = encode(camp) }
        for night in state.camps.trip { items[key(night.date)] = encode(night) }
        if let shown = state.camps.shown { items["shown"] = encode(shown) }
        for (field, value) in fields(state.settings) { items["settings/" + field] = value }
        for (field, value) in fields(state.units) { items["units/" + field] = value }
        return items
    }

    static func key(_ date: NightDate) -> String {
        String(format: "night/%04d-%02d-%02d", date.year, date.month, date.day)
    }

    static func stamping(_ new: SyncedState, changedFrom old: SyncedState, at now: Date) -> SyncedState {
        let before = items(old), after = items(new)
        var stamped = new
        for key in Set(before.keys).union(after.keys) where before[key] != after[key] {
            stamped.changedAt[key] = now
        }
        return stamped
    }

    static func merge(_ received: SyncedState, into local: SyncedState) -> SyncedState {
        let mine = items(local), theirs = items(received)
        var merged: [String: Data] = [:]
        for key in Set(mine.keys).union(theirs.keys) {
            let mineAt = local.changedAt[key] ?? .distantPast, theirsAt = received.changedAt[key] ?? .distantPast
            let takesTheirs = switch (mine[key], theirs[key]) {
            case _ where mineAt != theirsAt: theirsAt > mineAt
            case let (mine?, theirs?): mine.lexicographicallyPrecedes(theirs)
            case (nil, _): true
            case (_, nil): false
            }
            merged[key] = takesTheirs ? theirs[key] : mine[key]
        }

        let names = (local.camps.saved + received.camps.saved).map(\.name)
            .reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        let saved = names.compactMap { merged["camp/" + $0].flatMap { decode(CampLocation.self, $0) } }
        let trip = merged.filter { $0.key.hasPrefix("night/") }.values.compactMap { decode(TripNight.self, $0) }
        return SyncedState(
            camps: Camps(saved: saved, trip: trip, shown: merged["shown"].flatMap { decode(TripNight.self, $0) }),
            settings: rebuild(Settings.self, "settings/", from: merged) ?? local.settings,
            units: rebuild(DisplayUnits.self, "units/", from: merged) ?? local.units,
            changedAt: local.changedAt.merging(received.changedAt, uniquingKeysWith: max)
        )
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

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    private static func encode<Value: Encodable>(_ value: Value) -> Data {
        (try? encoder.encode(value)) ?? Data()
    }

    private static func decode<Value: Decodable>(_ type: Value.Type, _ data: Data) -> Value? {
        try? JSONDecoder().decode(type, from: data)
    }

    private static func fields<Value: Encodable>(_ value: Value) -> [String: Data] {
        guard let object = try? JSONSerialization.jsonObject(with: encode(value)) as? [String: Any] else { return [:] }
        return object.compactMapValues { try? JSONSerialization.data(withJSONObject: $0, options: [.fragmentsAllowed, .sortedKeys]) }
    }

    private static func rebuild<Value: Decodable>(_ type: Value.Type, _ prefix: String, from items: [String: Data]) -> Value? {
        var object: [String: Any] = [:]
        for (key, data) in items where key.hasPrefix(prefix) {
            object[String(key.dropFirst(prefix.count))] = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
        }
        return (try? JSONSerialization.data(withJSONObject: object)).flatMap { decode(type, $0) }
    }
}
