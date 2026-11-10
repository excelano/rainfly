// OvernightAlert.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
import UserNotifications

/// After 22:00, a notification when the latest forecast puts the rainfly on and the forecast
/// the night is judged against had it off. Once a night, and only through the system's
/// notification settings.
@MainActor
enum OvernightAlert {
    /// Posts the alert when it is due, unless `quiet`, which marks the night as alerted while
    /// another device does the alerting.
    @discardableResult
    static func check(_ model: ForecastModel, quiet: Bool = false, now: Date = .now) async -> Bool {
        guard model.preferences.overnightAlert, !model.wasAlerted,
              let night = model.night, let verdict = model.verdict, let decided = model.decided,
              let message = message(
                  night: night, verdict: verdict, decided: decided, decidedSettings: model.decidedSettings,
                  settings: model.settings, units: model.preferences.units, at: now
              )
        else { return false }
        model.markAlerted()
        if !quiet { await post(message) }
        return !quiet
    }

    /// The alert's text when the forecast has gone from off to on overnight, nil otherwise.
    static func message(
        night: NightForecast, verdict: Verdict, decided: NightForecast, decidedSettings: Settings, settings: Settings,
        units: DisplayUnits, at now: Date
    ) -> (title: String, body: String)? {
        let window = NightWindow(night, packByMinutes: settings.packByMinutes)
        guard window.phase(at: now) == .overnight, verdict.flyOn,
              !FlyEngine.evaluate(decided, settings: decidedSettings).flyOn, let headline = verdict.headline
        else { return nil }
        let text = VerdictText(night: night, verdict: verdict, settings: settings, units: units)
        let decidedAt = text.clock(NightWindow.decidedAt(decided))
        return ("Put the rainfly on", "\(text.describe(headline)). At \(decidedAt), Rainfly said it could stay off.")
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
