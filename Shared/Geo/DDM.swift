// DDM.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// One axis of a coordinate in degrees and decimal minutes,
/// held in integer thousandths of a minute so formatting never produces "60.000".
struct DDM: Equatable {
    var isLatitude: Bool
    var isNegative: Bool
    var degrees: Int
    var minutes: Int
    var thousandths: Int

    init(isLatitude: Bool, isNegative: Bool, degrees: Int, minutes: Int, thousandths: Int) {
        self.isLatitude = isLatitude
        self.isNegative = isNegative
        self.degrees = degrees
        self.minutes = minutes
        self.thousandths = thousandths
    }

    init(_ value: Double, isLatitude: Bool) {
        let total = Int((abs(value) * 60_000).rounded())
        self.init(
            isLatitude: isLatitude,
            isNegative: value < 0 && total > 0,
            degrees: total / 60_000,
            minutes: total % 60_000 / 1000,
            thousandths: total % 1000
        )
    }

    var value: Double {
        let magnitude = Double(degrees) + (Double(minutes) + Double(thousandths) / 1000) / 60
        return isNegative ? -magnitude : magnitude
    }

    var hemisphere: String {
        isLatitude ? (isNegative ? "S" : "N") : (isNegative ? "W" : "E")
    }

    var degreeText: String {
        String(format: isLatitude ? "%02d" : "%03d", degrees)
    }

    var minuteText: String {
        String(format: "%02d.%03d", minutes, thousandths)
    }

    /// "N 29° 45.123" / "W 095° 22.456"
    var text: String {
        "\(hemisphere) \(degreeText)° \(minuteText)"
    }
}
