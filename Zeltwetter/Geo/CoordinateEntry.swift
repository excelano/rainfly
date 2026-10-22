// CoordinateEntry.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// The editable fields of a DDM coordinate, one Digital Crown target each.
/// Every field wraps within its own range without carrying into its neighbour,
/// so turning one digit never disturbs the digits already set.
struct CoordinateEntry: Equatable {
    enum Field: Int, CaseIterable {
        case latHemisphere, latDegrees, latMinutes, latHundredths, latTens, latOnes
        case lonHemisphere, lonDegrees, lonMinutes, lonHundredths, lonTens, lonOnes

        var isLatitude: Bool { rawValue < Field.lonHemisphere.rawValue }
    }

    var latitude: DDM
    var longitude: DDM

    init(latitude: Double, longitude: Double) {
        self.latitude = DDM(latitude, isLatitude: true)
        self.longitude = DDM(longitude, isLatitude: false)
        Self.clamp(&self.latitude, to: 89)
        Self.clamp(&self.longitude, to: 179)
    }

    /// A pole or the antimeridian becomes the nearest value the fields can hold.
    private static func clamp(_ axis: inout DDM, to degrees: Int) {
        guard axis.degrees > degrees else { return }
        axis.degrees = degrees
        axis.minutes = 59
        axis.thousandths = 999
    }

    mutating func adjust(_ field: Field, by steps: Int) {
        if field.isLatitude {
            Self.step(&latitude, field, by: steps)
        } else {
            Self.step(&longitude, field, by: steps)
        }
    }

    /// The text of one field as shown on screen.
    func text(_ field: Field) -> String {
        let axis = field.isLatitude ? latitude : longitude
        switch field {
        case .latHemisphere, .lonHemisphere: return axis.hemisphere
        case .latDegrees, .lonDegrees: return axis.degreeText
        case .latMinutes, .lonMinutes: return String(format: "%02d", axis.minutes)
        case .latHundredths, .lonHundredths: return String(axis.thousandths / 100)
        case .latTens, .lonTens: return String(axis.thousandths / 10 % 10)
        case .latOnes, .lonOnes: return String(axis.thousandths % 10)
        }
    }

    private static func step(_ axis: inout DDM, _ field: Field, by steps: Int) {
        switch field {
        case .latHemisphere, .lonHemisphere:
            if steps % 2 != 0 { axis.isNegative.toggle() }
        case .latDegrees, .lonDegrees:
            axis.degrees = wrap(axis.degrees + steps, axis.isLatitude ? 90 : 180)
        case .latMinutes, .lonMinutes:
            axis.minutes = wrap(axis.minutes + steps, 60)
        case .latHundredths, .lonHundredths:
            axis.thousandths = replaceDigit(of: axis.thousandths, place: 100, by: steps)
        case .latTens, .lonTens:
            axis.thousandths = replaceDigit(of: axis.thousandths, place: 10, by: steps)
        case .latOnes, .lonOnes:
            axis.thousandths = replaceDigit(of: axis.thousandths, place: 1, by: steps)
        }
    }

    private static func replaceDigit(of value: Int, place: Int, by steps: Int) -> Int {
        let digit = value / place % 10
        return value + (wrap(digit + steps, 10) - digit) * place
    }

    private static func wrap(_ value: Int, _ count: Int) -> Int {
        (value % count + count) % count
    }
}
