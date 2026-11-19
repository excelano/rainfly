// NightCall.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// The advice a night was given: the pre-overnight forecast, the settings in force when it was
/// sealed, and the verdict they make over the overnight period. Sealed once and never recomputed.
struct NightCall: Codable, Equatable, Sendable {
    let forecast: NightForecast
    let settings: Settings
    let verdict: Verdict

    var anchor: Date { NightWindow.anchor(of: forecast) }

    /// Nil when the forecast was fetched at or after the anchor, too late to be advice before it.
    static func seal(_ forecast: NightForecast, settings: Settings) -> NightCall? {
        guard forecast.fetchedAt < NightWindow.anchor(of: forecast) else { return nil }
        return NightCall(forecast: forecast, settings: settings, verdict: FlyEngine.overnight(forecast, settings: settings))
    }
}
