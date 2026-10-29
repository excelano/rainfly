// SettingsStore.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// How values are shown. The engine and the stores always work in °C and m/s.
struct DisplayUnits: Codable, Equatable, Sendable {
    var fahrenheit: Bool
    var mph: Bool

    static var locale: DisplayUnits {
        let system = Locale.current.measurementSystem
        return DisplayUnits(fahrenheit: system == .us, mph: system != .metric)
    }

    func temperature(_ celsius: Double) -> Double { fahrenheit ? celsius * 9 / 5 + 32 : celsius }
    func celsius(_ shown: Double) -> Double { fahrenheit ? (shown - 32) * 5 / 9 : shown }

    /// A difference between two temperatures, which converts without the offset.
    func temperatureSpan(_ celsius: Double) -> Double { fahrenheit ? celsius * 9 / 5 : celsius }
    func celsiusSpan(_ shown: Double) -> Double { fahrenheit ? shown * 5 / 9 : shown }

    func speed(_ metersPerSecond: Double) -> Double { mph ? metersPerSecond / Self.metersPerSecondPerMph : metersPerSecond }
    func metersPerSecond(_ shown: Double) -> Double { mph ? shown * Self.metersPerSecondPerMph : shown }

    var speedUnit: String { mph ? "mph" : "m/s" }

    private static let metersPerSecondPerMph = 0.44704
}

/// The settings that are not thresholds.
struct Preferences: Codable, Equatable, Sendable {
    var units = DisplayUnits.locale
    var pressureWatch = true
    /// The iPhone's dew diary; it stays on the device and is not synced.
    var dewDiary = false
    var diaryReminder = true
    /// Whether answered diary nights are shared with Excelano, under `diaryID`.
    var shareDiary = false
    /// Made the first time sharing is turned on, and replaced when the user asks for a new one.
    var diaryID: UUID?

    init() {}

    /// A field missing from saved preferences keeps its default.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        units = try c.decodeIfPresent(DisplayUnits.self, forKey: .units) ?? .locale
        pressureWatch = try c.decodeIfPresent(Bool.self, forKey: .pressureWatch) ?? true
        dewDiary = try c.decodeIfPresent(Bool.self, forKey: .dewDiary) ?? false
        diaryReminder = try c.decodeIfPresent(Bool.self, forKey: .diaryReminder) ?? true
        shareDiary = try c.decodeIfPresent(Bool.self, forKey: .shareDiary) ?? false
        diaryID = try c.decodeIfPresent(UUID.self, forKey: .diaryID)
    }
}

/// Settings and preferences in the App Group's defaults, shared with the complication.
struct SettingsStore {
    let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults(suiteName: AppGroup.id) ?? .standard) {
        self.defaults = defaults
    }

    var settings: Settings {
        get { load("settings") ?? Settings() }
        nonmutating set { save(newValue, "settings") }
    }

    var preferences: Preferences {
        get { load("preferences") ?? Preferences() }
        nonmutating set { save(newValue, "preferences") }
    }

    var changedAt: [String: Date]? {
        get { load("changedAt") }
        nonmutating set { save(newValue, "changedAt") }
    }

    var syncedAt: Date? {
        load("syncedAt")
    }

    /// The state last sent to the other device, so an unchanged one is not sent again.
    var lastSentState: Data? {
        get { defaults.data(forKey: "lastSentState") }
        nonmutating set { defaults.set(newValue, forKey: "lastSentState") }
    }

    /// Whether the paired watch is installed and watching the pressure, as it last said.
    var watchWatchesPressure: Bool {
        get { load("watchWatchesPressure") ?? false }
        nonmutating set { save(newValue, "watchWatchesPressure") }
    }

    private func load<Value: Decodable>(_ key: String) -> Value? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(Value.self, from: $0) }
    }

    private func save<Value: Encodable>(_ value: Value, _ key: String) {
        defaults.set(try? JSONEncoder().encode(value), forKey: key)
    }
}
