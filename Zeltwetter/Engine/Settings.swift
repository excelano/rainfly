// Settings.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// The thresholds the engine decides with. A new value starts at the defaults.
struct Settings: Codable, Equatable, Sendable {
    var rainChance = 0.20
    var morningRainChance = 0.20
    var windRainMS = 8.0
    var dewSpreadC = 3.0
    var clearSky = 0.30
    var calmWindMS = 3.0
    var coldC = 10.0
    var ventHumidity = 0.85
    /// Minutes after local midnight on the morning after the night.
    var packByMinutes = 8 * 60
    /// The sleeping bag's comfort rating; nil turns the bag check off.
    var bagRatingC: Double?
}
