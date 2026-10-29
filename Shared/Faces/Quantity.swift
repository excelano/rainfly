// Quantity.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// A setting stored in °C, m/s or a fraction and shown in the chosen unit, with the range
/// and step the editor moves in.
struct Quantity: Sendable {
    let title: String
    let range: ClosedRange<Double>
    let step: Double
    let shown: @Sendable (Double) -> Double
    let stored: @Sendable (Double) -> Double
    let suffix: String

    /// The stored value as shown, on the nearest step inside the range.
    func display(_ value: Double) -> Double {
        let snapped = (shown(value) / step).rounded() * step
        return min(max(snapped, range.lowerBound), range.upperBound)
    }

    func text(_ value: Double) -> String {
        format(display(value))
    }

    func format(_ shown: Double) -> String {
        shown.formatted(.number.precision(.fractionLength(step < 1 ? 1 : 0))) + suffix
    }

    private static func percent(_ title: String, _ range: ClosedRange<Double>) -> Quantity {
        Quantity(title: title, range: range, step: 5, shown: { $0 * 100 }, stored: { $0 / 100 }, suffix: "%")
    }

    private static func temperature(_ title: String, _ units: DisplayUnits, c: ClosedRange<Double>, f: ClosedRange<Double>) -> Quantity {
        Quantity(
            title: title, range: units.fahrenheit ? f : c, step: 1,
            shown: units.temperature, stored: units.celsius, suffix: "°"
        )
    }

    private static func speed(_ title: String, _ units: DisplayUnits, ms: ClosedRange<Double>, mph: ClosedRange<Double>) -> Quantity {
        Quantity(
            title: title, range: units.mph ? mph : ms, step: units.mph ? 1 : 0.5,
            shown: units.speed, stored: units.metersPerSecond, suffix: " " + units.speedUnit
        )
    }

    static let rainChance = percent("Chance of rain at or above", 5...100)
    static let morningRainChance = percent("Chance of rain at or above", 5...100)
    static let clearSky = percent("Cloud cover below", 5...80)
    static let ventHumidity = percent("Humidity at or above", 50...100)

    static func windRain(_ units: DisplayUnits) -> Quantity {
        speed("Wind above", units, ms: 3...20, mph: 5...45)
    }

    static func calmWind(_ units: DisplayUnits) -> Quantity {
        speed("Wind below", units, ms: 0.5...8, mph: 1...18)
    }

    static func dewSpread(_ units: DisplayUnits) -> Quantity {
        Quantity(
            title: "Dew-point gap at or below", range: units.fahrenheit ? 1...11 : 0.5...6, step: units.fahrenheit ? 1 : 0.5,
            shown: units.temperatureSpan, stored: units.celsiusSpan, suffix: "°"
        )
    }

    static func cold(_ units: DisplayUnits) -> Quantity {
        temperature("Temperature below", units, c: -10...20, f: 15...68)
    }

    static func bagRating(_ units: DisplayUnits) -> Quantity {
        temperature("Comfort rating", units, c: -30...20, f: -20...68)
    }
}
