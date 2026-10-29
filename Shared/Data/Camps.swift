// Camps.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// A night of the trip: the camp shown on the evening of `date`.
struct TripNight: Codable, Hashable, Sendable {
    let date: NightDate
    let campName: String
}

/// The saved camps and the trip planned across them. A camp is known by its name, which
/// is unique and never "Here"; the trip holds at most one camp per night, in date order.
struct Camps: Codable, Equatable, Sendable {
    private(set) var saved: [CampLocation] = []
    private(set) var trip: [TripNight] = []

    init() {}

    init(saved: [CampLocation], trip: [TripNight]) {
        self.saved = saved
        let names = Set(saved.map(\.name))
        self.trip = trip.filter { names.contains($0.campName) }.sorted { $0.date < $1.date }
    }

    /// The camp for the evening of `date`: the trip's, or the watch's own position.
    func campName(on date: NightDate) -> String {
        trip.first { $0.date == date }?.campName ?? CampLocation.hereName
    }

    func camp(named name: String) -> CampLocation? {
        saved.first { $0.name == name }
    }

    /// Saves `camp` under its name, or its name with the first free number after it.
    @discardableResult
    mutating func add(_ camp: CampLocation) -> CampLocation {
        let trimmed = camp.name.trimmingCharacters(in: .whitespaces)
        let base = trimmed.isEmpty ? "Camp" : trimmed
        let taken = Set(saved.map(\.name) + [CampLocation.hereName])
        let name = taken.contains(base) ? (2...).lazy.map { "\(base) \($0)" }.first { !taken.contains($0) }! : base
        let named = CampLocation(name: name, latitude: camp.latitude, longitude: camp.longitude, timeZoneID: camp.timeZoneID)
        saved.append(named)
        return named
    }

    /// Removes the camp and its nights.
    mutating func remove(named name: String) {
        saved.removeAll { $0.name == name }
        trip.removeAll { $0.campName == name }
    }

    /// Plans `campName` for the night of `date`, replacing that night's camp; "Here" clears it.
    mutating func plan(_ campName: String, on date: NightDate) {
        trip.removeAll { $0.date == date }
        guard camp(named: campName) != nil else { return }
        trip.append(TripNight(date: date, campName: campName))
        trip.sort { $0.date < $1.date }
    }

    mutating func removeNight(on date: NightDate) {
        trip.removeAll { $0.date == date }
    }

    /// Drops the nights before `date`, which have passed.
    mutating func removeNights(before date: NightDate) {
        trip.removeAll { $0.date < date }
    }
}

extension Store where Value == Camps {
    static var camps: Store { Store(name: "camps") }
}
