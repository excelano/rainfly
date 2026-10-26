// NightDate.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// A night named by the calendar date of its evening. It carries no zone, so a trip night
/// means the same evening at the camp as on the watch.
struct NightDate: Codable, Hashable, Comparable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(_ date: Date, calendar: Calendar) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    /// The start of the evening's day in `calendar`'s zone.
    func start(in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    func adding(days: Int) -> NightDate {
        let calendar = Self.utc
        return NightDate(calendar.date(byAdding: .day, value: days, to: start(in: calendar)) ?? .distantPast, calendar: calendar)
    }

    func days(since other: NightDate) -> Int {
        let calendar = Self.utc
        return calendar.dateComponents([.day], from: other.start(in: calendar), to: start(in: calendar)).day ?? 0
    }

    static func < (lhs: NightDate, rhs: NightDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    /// The night that matters at `now`: last night until pack-by, tonight from then on.
    static func covering(_ now: Date, packByMinutes: Int, calendar: Calendar) -> NightDate {
        let packBy = calendar.date(bySettingHour: packByMinutes / 60, minute: packByMinutes % 60, second: 0, of: now) ?? now
        let today = NightDate(now, calendar: calendar)
        return now < packBy ? today.adding(days: -1) : today
    }

    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
}
