// Verdict.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// Declared in headline priority order, highest first.
enum Trigger: String, Codable, CaseIterable, Sendable {
    case storm, rain, windRain, frost, dew, morningRain, cold

    var priority: Int { Self.allCases.firstIndex(of: self)! }
}

/// A trigger and the earliest hour it fires.
struct Firing: Codable, Equatable, Sendable {
    let trigger: Trigger
    let at: Date
}

struct BagWarning: Codable, Equatable, Sendable {
    let lowC: Double
    let ratingC: Double
}

struct Verdict: Codable, Equatable, Sendable {
    let flyOn: Bool
    /// Sorted by priority, then time.
    let firings: [Firing]
    let ventAdvice: Bool
    let bagWarning: BagWarning?
    let dryBy: Date?

    var headline: Firing? { firings.first }

    func firing(_ trigger: Trigger) -> Firing? {
        firings.first { $0.trigger == trigger }
    }
}
