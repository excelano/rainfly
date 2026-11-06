// NightSun.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// A night where the sun never sets or never rises.
enum PolarSky: String, Codable, Sendable {
    case midnightSun, polarNight
}

/// The sunset that starts a night and the sunrise that ends it, chosen from the sun events
/// the forecast gives for the days around the evening.
struct NightSun: Equatable, Sendable {
    let sunset: Date
    let sunrise: Date
    let polar: PolarSky?

    /// The first sunset from noon on the evening to noon the next day, since far north it
    /// can fall after midnight, and the first sunrise after it. Where the sun stays up or
    /// stays down, the night runs from 9 PM to 6 AM. Nil when a camp too far from the poles
    /// for either has no sunset, which means the forecast left it out.
    init?(sunsets: [Date], sunrises: [Date], evening: Date, latitude: Double, calendar: Calendar) {
        let at = { (hours: Int) in calendar.date(byAdding: .hour, value: hours, to: evening) ?? evening }
        let usualSunset = at(Self.usualSunsetHour)
        let usualSunrise = at(24 + Self.usualSunriseHour)
        if let sunset = sunsets.filter({ $0 >= at(12) && $0 < at(36) }).min() {
            self.sunset = sunset
            if let sunrise = sunrises.filter({ $0 > sunset && $0 < sunset.addingTimeInterval(86_400) }).min() {
                self.sunrise = sunrise
                polar = nil
            } else {
                sunrise = max(usualSunrise, sunset.addingTimeInterval(3600))
                polar = .polarNight
            }
            return
        }
        guard abs(latitude) >= Self.polarLatitude else { return nil }
        sunset = usualSunset
        sunrise = usualSunrise
        let month = calendar.component(.month, from: evening)
        let northernSummer = (3...9).contains(month)
        polar = northernSummer == (latitude > 0) ? .midnightSun : .polarNight
    }

    static let usualSunsetHour = 21
    static let usualSunriseHour = 6
    /// Below this latitude the sun sets and rises every day of the year.
    static let polarLatitude = 63.0
}
