// CoordinateTextTests.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
import Testing
@testable import Zeltwetter_Watch_App

struct CoordinateTextTests {
    @Test func decimalDegrees() throws {
        #expect(CoordinateText.parse("39.9389", isLatitude: true) == 39.9389)
        #expect(CoordinateText.parse("-105.6106", isLatitude: false) == -105.6106)
        #expect(CoordinateText.parse("105.6106 W", isLatitude: false) == -105.6106)
        #expect(CoordinateText.parse("s 12.5", isLatitude: true) == -12.5)
    }

    @Test func degreesAndDecimalMinutes() throws {
        let latitude = try #require(CoordinateText.parse("N 39° 56.334", isLatitude: true))
        #expect(abs(latitude - (39 + 56.334 / 60)) < 1e-9)
        let longitude = try #require(CoordinateText.parse("W 105° 36.636'", isLatitude: false))
        #expect(abs(longitude + (105 + 36.636 / 60)) < 1e-9)
        #expect(CoordinateText.parse("39 56.334", isLatitude: true) != nil)
    }

    @Test func rejectsWhatIsNotACoordinate() {
        #expect(CoordinateText.parse("", isLatitude: true) == nil)
        #expect(CoordinateText.parse("91", isLatitude: true) == nil)
        #expect(CoordinateText.parse("181", isLatitude: false) == nil)
        #expect(CoordinateText.parse("39 60.5", isLatitude: true) == nil)
        #expect(CoordinateText.parse("39.5 30", isLatitude: true) == nil)
        #expect(CoordinateText.parse("E 39", isLatitude: true) == nil)
        #expect(CoordinateText.parse("-S 39", isLatitude: true) == nil)
        #expect(CoordinateText.parse("N 39 S", isLatitude: true) == nil)
        #expect(CoordinateText.parse("Lost Lake", isLatitude: true) == nil)
    }
}
