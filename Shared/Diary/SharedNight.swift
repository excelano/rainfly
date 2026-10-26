// SharedNight.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// A diary night as it is shared with Excelano: the camp's position rounded to 0.1°, no camp
/// name anywhere, and the forecast and history as hours alone.
struct SharedNight: Equatable {
    let diaryID: UUID
    let night: String
    let latitude: Double
    let longitude: Double
    let timeZoneID: String
    let found: DewObservation.Kind
    let openSky: Bool
    let forecast: SharedHours
    let history: SharedHours?
    let settings: Settings
    let appVersion: String

    /// Nil for a night with no forecast, or with no answer to share.
    init?(_ night: DiaryNight, diaryID: UUID, settings: Settings, appVersion: String) {
        guard let pitched = night.pitched, let observation = night.observation, observation.kind != .notChecked else { return nil }
        self.diaryID = diaryID
        self.night = String(format: "%04d-%02d-%02d", night.date.year, night.date.month, night.date.day)
        latitude = Self.rounded(pitched.location.latitude)
        longitude = Self.rounded(pitched.location.longitude)
        timeZoneID = pitched.location.timeZoneID
        found = observation.kind
        openSky = observation.openSky
        forecast = SharedHours(pitched)
        history = night.history.map(SharedHours.init)
        self.settings = settings
        self.appVersion = appVersion
    }

    /// The same diary ID, night and position always give the same name, so a resend replaces.
    var recordName: String {
        "\(diaryID.uuidString.lowercased())_\(night)_\(String(format: "%.1f", latitude))_\(String(format: "%.1f", longitude))"
    }

    /// About 11 km: enough to place the weather, not enough to find a house.
    static func rounded(_ degrees: Double) -> Double {
        (degrees * 10).rounded() / 10
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()
}

/// Where a night was last shared, so a resend under a new diary ID can remove the old copy.
struct SharedMark: Codable, Equatable {
    let recordName: String
    let at: Date
}

extension DewDiary {
    /// Answered nights never sent, or whose answer or history changed since they were.
    func needingShare() -> [DiaryNight] {
        nights.filter { night in
            guard let observation = night.observation, observation.kind != .notChecked else { return false }
            guard let shared = night.shared else { return true }
            return observation.at > shared.at || (night.history?.fetchedAt ?? .distantPast) > shared.at
        }
    }

    mutating func markShared(_ mark: SharedMark?, campName: String, on date: NightDate) {
        guard let index = nights.firstIndex(where: { $0.campName == campName && $0.date == date }) else { return }
        nights[index].shared = mark
    }
}
