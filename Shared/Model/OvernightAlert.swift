// OvernightAlert.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
import UserNotifications

/// After 22:00, a notification when the latest forecast puts the rainfly on and the night's
/// call had it off. Once a night, and only through the system's notification settings.
@MainActor
enum OvernightAlert {
    /// Posts the alert when it is due, unless `quiet`, which marks the night as alerted while
    /// another device does the alerting.
    @discardableResult
    static func check(_ model: ForecastModel, quiet: Bool = false, now: Date = .now) async -> Bool {
        guard model.preferences.overnightAlert, !model.wasAlerted,
              let fetches = model.fetches, let call = fetches.call,
              let message = message(
                  night: fetches.latest, call: call, settings: model.settings, units: model.preferences.units, at: now
              )
        else { return false }
        model.markAlerted()
        if !quiet { await post(message) }
        return !quiet
    }

    /// The alert's text when the forecast has gone from off to on overnight, nil otherwise.
    static func message(
        night: NightForecast, call: NightCall, settings: Settings, units: DisplayUnits, at now: Date
    ) -> (title: String, body: String)? {
        let ahead = VerdictText(night: night, settings: settings, units: units).ahead(of: now)
        guard ahead.window.phase(at: now) == .overnight, !call.verdict.flyOn, let headline = ahead.verdict.headline else { return nil }
        return ("Put the rainfly on", "\(ahead.describe(headline)). At \(ahead.clock(call.anchor)), Rainfly said it could stay off.")
    }

    static func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    static func key(_ campName: String, _ date: NightDate) -> String {
        "\(campName)|\(date.year)-\(date.month)-\(date.day)"
    }

    private static func post(_ message: (title: String, body: String)) async {
        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        content.sound = .default
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "overnight", content: content, trigger: nil))
    }
}
