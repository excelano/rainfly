// ZeltwetterPhoneApp.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

@main
struct ZeltwetterPhoneApp: App {
    var body: some Scene {
        WindowGroup {
            TentGlyph(flyOn: true)
                .frame(width: 120, height: 120)
                .foregroundStyle(.tint)
        }
    }
}
