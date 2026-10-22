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

extension Settings {
    /// A field missing from saved settings, as after an update adds one, keeps its default.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings()
        rainChance = try c.decodeIfPresent(Double.self, forKey: .rainChance) ?? d.rainChance
        morningRainChance = try c.decodeIfPresent(Double.self, forKey: .morningRainChance) ?? d.morningRainChance
        windRainMS = try c.decodeIfPresent(Double.self, forKey: .windRainMS) ?? d.windRainMS
        dewSpreadC = try c.decodeIfPresent(Double.self, forKey: .dewSpreadC) ?? d.dewSpreadC
        clearSky = try c.decodeIfPresent(Double.self, forKey: .clearSky) ?? d.clearSky
        calmWindMS = try c.decodeIfPresent(Double.self, forKey: .calmWindMS) ?? d.calmWindMS
        coldC = try c.decodeIfPresent(Double.self, forKey: .coldC) ?? d.coldC
        ventHumidity = try c.decodeIfPresent(Double.self, forKey: .ventHumidity) ?? d.ventHumidity
        packByMinutes = try c.decodeIfPresent(Int.self, forKey: .packByMinutes) ?? d.packByMinutes
        bagRatingC = try c.decodeIfPresent(Double.self, forKey: .bagRatingC)
    }

    /// The trigger thresholds back at their defaults; pack-by and the bag rating are kept.
    func resettingThresholds() -> Settings {
        var reset = Settings()
        reset.packByMinutes = packByMinutes
        reset.bagRatingC = bagRatingC
        return reset
    }
}
