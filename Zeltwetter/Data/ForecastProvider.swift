// ForecastProvider.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// A source of night forecasts, kept apart so the engine and the tests never see WeatherKit.
protocol ForecastProvider: Sendable {
    /// The night that begins on the evening of `evening`, a start of day in the camp's zone,
    /// with hours from sunset to noon the next day.
    func night(at camp: CampLocation, evening: Date) async throws -> NightForecast
    func attribution() async throws -> Attribution
}

/// The data source's mark and legal page, which the detail screen must show.
struct Attribution: Equatable, Sendable {
    let markURL: URL?
    let legalURL: URL

    /// Shown when the attribution cannot be fetched, as when the watch is offline.
    static let fallback = Attribution(
        markURL: nil,
        legalURL: URL(string: "https://weatherkit.apple.com/legal-attribution.html")!
    )
}

enum ForecastError: LocalizedError {
    case noSunset
    case noLocation

    var errorDescription: String? {
        switch self {
        case .noSunset: "The sun doesn't set here tonight."
        case .noLocation: "Location is unavailable. Allow it in Settings."
        }
    }
}
