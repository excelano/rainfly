// OvernightStyle.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

extension View {
    /// Overnight the screen goes dark, and red unless the red screen is turned off, so it
    /// keeps eyes used to the dark like a headlamp's red light.
    func overnightStyle(isOvernight: Bool, red: Bool) -> some View {
        preferredColorScheme(isOvernight ? .dark : nil)
            .colorMultiply(isOvernight && red ? Color(red: 1, green: 0.3, blue: 0.25) : .white)
    }
}
