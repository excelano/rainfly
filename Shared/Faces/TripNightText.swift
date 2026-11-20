// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

struct TripNightText {
    let text: VerdictText
    let fetches: NightFetches
    let phase: NightWindow.Phase?
    let now: Date

    init(_ fetches: NightFetches, of night: TripNight, tonight: NightDate, settings: Settings, units: DisplayUnits, at now: Date) {
        text = VerdictText(night: fetches.latest, settings: settings, units: units)
        self.fetches = fetches
        phase = night.date == tonight ? text.window.phase(at: now) : nil
        self.now = now
    }

    var row: (flyOn: Bool, headline: String, detail: String) {
        guard let phase, phase != .evening else { return (text.verdict.flyOn, text.headline, text.reason) }
        let face = ComplicationFace(text, at: now, fetches: fetches)
        return (face.flyOn ?? text.verdict.flyOn, face.headline, face.detail)
    }
}
