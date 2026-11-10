// PressureLog.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

struct PressureSample: Codable, Equatable, Sendable {
    let date: Date
    let hPa: Double
}

/// The overnight pressure readings, a rolling buffer, and when the last warning went out.
struct PressureLog: Codable, Equatable, Sendable {
    static let kept: TimeInterval = 12 * 3600
    static let span: TimeInterval = 3 * 3600
    /// How old the newest reading can be and still describe the pressure now.
    static let fresh: TimeInterval = 90 * 60
    static let fallHPa = 1.5

    private(set) var samples: [PressureSample] = []
    var warnedAt: Date?

    mutating func record(_ sample: PressureSample) {
        samples = (samples + [sample])
            .filter { $0.date > sample.date.addingTimeInterval(-Self.kept) && $0.date <= sample.date }
            .sorted { $0.date < $1.date }
    }

    /// Whether the newest reading sits `fallHPa` or more below the highest of the `span`
    /// before it.
    var isFallingFast: Bool {
        guard let latest = samples.last else { return false }
        let earlier = samples.filter { $0.date >= latest.date.addingTimeInterval(-Self.span) && $0.date < latest.date }
        guard let peak = earlier.map(\.hPa).max() else { return false }
        return peak - latest.hPa >= Self.fallHPa
    }

    enum Trend: Equatable, Sendable { case fallingFast, falling, steady, rising }

    /// How the pressure has moved over the `span` before the newest reading, when that reading
    /// is fresh at `now` and the readings cover at least an hour of the span.
    func trend(at now: Date) -> (trend: Trend, hours: Int)? {
        guard let latest = samples.last, latest.date >= now.addingTimeInterval(-Self.fresh) else { return nil }
        let earlier = samples.filter { $0.date >= latest.date.addingTimeInterval(-Self.span) && $0.date < latest.date }
        guard let first = earlier.first, latest.date.timeIntervalSince(first.date) >= 3600 else { return nil }
        let change = latest.hPa - (earlier.map(\.hPa).max() ?? first.hPa)
        let rise = latest.hPa - (earlier.map(\.hPa).min() ?? first.hPa)
        let hours = Int((latest.date.timeIntervalSince(first.date) / 3600).rounded())
        if change <= -Self.fallHPa { return (.fallingFast, hours) }
        if change <= -0.5 { return (.falling, hours) }
        if rise >= 0.5 { return (.rising, hours) }
        return (.steady, hours)
    }

    /// Warn when the pressure falls fast while the fly is off, once a night.
    func shouldWarn(verdict: Verdict, nightStart: Date) -> Bool {
        guard !verdict.flyOn, isFallingFast else { return false }
        return warnedAt.map { $0 < nightStart } ?? true
    }
}
