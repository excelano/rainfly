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

    /// The call `forecast` makes with `settings`, whenever it was fetched.
    init(_ forecast: NightForecast, settings: Settings) {
        self.forecast = forecast
        self.settings = settings
        verdict = FlyEngine.overnight(forecast, settings: settings)
    }

    /// Nil when the forecast was fetched at or after the anchor, too late to be advice before it.
    static func seal(_ forecast: NightForecast, settings: Settings) -> NightCall? {
        forecast.fetchedAt < NightWindow.anchor(of: forecast) ? NightCall(forecast, settings: settings) : nil
    }

    /// Whether this call replaces `other` for the same night: the one made from the later
    /// forecast stands, so two devices that each sealed one end up with the same call.
    func supersedes(_ other: NightCall?) -> Bool {
        other.map { $0.forecast.fetchedAt < forecast.fetchedAt } ?? true
    }

    /// The overnight period's closest dew-point gap in the call's forecast.
    var closestSpread: Double? {
        NightWindow(forecast, packByMinutes: settings.packByMinutes, from: anchor).closestSpread
    }
}
