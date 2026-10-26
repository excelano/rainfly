// CoordinateText.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// One axis of a typed coordinate: decimal degrees ("39.9389", "-105.6106") or degrees and
/// decimal minutes ("N 39° 56.334"), with the hemisphere as a letter at either end or a
/// leading minus.
enum CoordinateText {
    static func parse(_ text: String, isLatitude: Bool) -> Double? {
        var rest = text.trimmingCharacters(in: .whitespaces).uppercased()
        let positive: Character = isLatitude ? "N" : "E"
        let negative: Character = isLatitude ? "S" : "W"
        var sign = 1.0
        var signs = 0
        if let first = rest.first, first == positive || first == negative {
            sign = first == negative ? -1 : 1
            signs += 1
            rest.removeFirst()
        }
        if let last = rest.last, last == positive || last == negative {
            sign = last == negative ? -1 : 1
            signs += 1
            rest.removeLast()
        }
        rest = rest.trimmingCharacters(in: .whitespaces)
        if rest.hasPrefix("-") {
            sign = -1
            signs += 1
            rest.removeFirst()
        }
        guard signs <= 1 else { return nil }

        let numbers = rest.split { !"0123456789.".contains($0) }.map(String.init)
        let value: Double
        switch numbers.count {
        case 1:
            guard let degrees = Double(numbers[0]) else { return nil }
            value = degrees
        case 2:
            guard let degrees = Int(numbers[0]), let minutes = Double(numbers[1]), minutes < 60 else { return nil }
            value = Double(degrees) + minutes / 60
        default:
            return nil
        }
        guard rest.allSatisfy({ "0123456789. °'′".contains($0) }), value <= (isLatitude ? 90 : 180) else { return nil }
        return sign * value
    }
}
