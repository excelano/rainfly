// DewObservation.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// What was found in the morning on something left under the sky.
struct DewObservation: Codable, Equatable, Sendable {
    /// Light dew is spots or edges; wet is damp all over or beaded, enough to pack a wet fly.
    enum Kind: String, Codable, CaseIterable, Sendable {
        case dry, lightDew, wet, frost, rain, notChecked

        /// Whether the night counts as wet, dry, or neither when it is judged.
        var foundMoisture: Bool? {
            switch self {
            case .wet, .frost: true
            case .dry: false
            case .lightDew, .rain, .notChecked: nil
            }
        }
    }

    let kind: Kind
    /// False when what was checked stood under trees, which block most of the cooling.
    let openSky: Bool
    let at: Date
}
