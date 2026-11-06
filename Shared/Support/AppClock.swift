// AppClock.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// The time the app runs on: the device's, or in a Debug demo the one `--at` sets.
enum AppClock {
    static var now: Date {
        #if DEBUG
        Demo.now ?? Date()
        #else
        Date()
        #endif
    }
}
