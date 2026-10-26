// AgeColor.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

extension VerdictText.Staleness {
    /// The forecast age's color: orange past twelve hours, red past a day.
    var color: Color {
        switch self {
        case .fresh: .secondary
        case .aging: .orange
        case .stale: .red
        }
    }
}
