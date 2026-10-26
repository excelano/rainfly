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

    /// Warn when the pressure falls fast while the fly is off, once a night.
    func shouldWarn(verdict: Verdict, nightStart: Date) -> Bool {
        guard !verdict.flyOn, isFallingFast else { return false }
        return warnedAt.map { $0 < nightStart } ?? true
    }
}
