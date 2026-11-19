// MorningText.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// The words for the morning after a night: what Rainfly expected when it made the night's call.
struct MorningText {
    /// The latest forecast, for the camp and the clock.
    let text: VerdictText
    /// Nil for a night with no forecast before the anchor.
    let call: NightCall?

    let caption = "Last night"

    /// Whether the call had the rainfly on.
    var flyOn: Bool { call?.verdict.flyOn ?? false }

    /// "Rainfly expected dew".
    var headline: String {
        call.map { "Rainfly expected \(Self.expectation(Self.firing($0.verdict)))" } ?? "Rainfly made no call last night"
    }

    /// "Expected dew", where there is no room for more.
    var brief: String {
        call.map { "Expected \(Self.expectation(Self.firing($0.verdict)))" } ?? "No call last night"
    }

    /// When tonight's forecast takes over: "12:00".
    var handoverTime: String { text.clock(text.window.handover) }

    /// What a call is remembered by: rain first, since it wets the tent whatever the dew does,
    /// then dew or frost, then cold when cold alone put the rainfly on.
    private static func firing(_ verdict: Verdict) -> Firing? {
        verdict.rain ?? verdict.condensation ?? verdict.firing(.cold)
    }

    /// What Rainfly expected of a night, for the morning question: "Rainfly expected dew".
    static func expected(_ firing: Firing?, afterRain: Bool = false) -> String {
        "Rainfly expected \(expectation(firing, afterRain: afterRain))"
    }

    /// Nil is a dry night, or no dew or frost when rain was asked about first.
    static func expectation(_ firing: Firing?, afterRain: Bool = false) -> String {
        guard let trigger = firing?.trigger else { return afterRain ? "no dew or frost" : "a dry night" }
        return expectation(trigger)
    }

    /// What a trigger means for the tent: "a storm", "rain", "dew", "a cold night".
    static func expectation(_ trigger: Trigger) -> String {
        switch trigger {
        case .storm: "a storm"
        case .rain, .windRain, .morningRain: "rain"
        case .frost: "frost"
        case .dew: "dew"
        case .cold: "a cold night"
        }
    }
}
