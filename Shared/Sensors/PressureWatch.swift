// PressureWatch.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import CoreMotion
import Foundation
import UserNotifications

/// Overnight warning of falling pressure while the fly is off. This is coarse sampling, not
/// continuous monitoring: the barometer is read for a few seconds on each background
/// refresh during the night, and watchOS grants only a few refreshes an hour, so a fall
/// shows up some time after it starts and a short dip between refreshes is missed.
@MainActor
struct PressureWatch {
    let store: Store<PressureLog>
    let sample: @MainActor () async -> Double?
    let warn: @MainActor (String) async -> Void

    static let message = "Pressure dropping fast — consider the rainfly."

    static func live() -> PressureWatch {
        PressureWatch(store: Store(name: "pressure"), sample: { await Barometer().read() }, warn: post)
    }

    enum Outcome: String, Codable, Sendable {
        case noForecast, outsideNight, noReading, recorded, warned
    }

    /// Takes a reading while `now` is inside the night, and warns when it shows a fast fall
    /// unless `quiet`, which keeps the log filling while another device does the warning.
    @discardableResult
    func check(night: NightForecast?, verdict: Verdict?, quiet: Bool = false, now: Date = .now) async -> Outcome {
        guard let night, let verdict else { return .noForecast }
        guard now >= night.sunset, now < night.sunrise else { return .outsideNight }
        guard let hPa = await sample() else { return .noReading }
        var log = store.load() ?? PressureLog()
        log.record(PressureSample(date: now, hPa: hPa))
        var outcome = Outcome.recorded
        if !quiet, log.shouldWarn(verdict: verdict, nightStart: night.sunset) {
            await warn(Self.message)
            log.warnedAt = now
            outcome = .warned
        }
        store.save(log)
        return outcome
    }

    /// The newest reading kept, for the Settings screen.
    var lastReading: Date? {
        store.load()?.samples.last?.date
    }

    /// A line for the Settings screen: why the barometer cannot be read, or when it last was.
    static var status: String {
        if !CMAltimeter.isRelativeAltitudeAvailable() { return "This device has no barometer." }
        switch CMAltimeter.authorizationStatus() {
        case .denied, .restricted:
            return "Motion & Fitness is off for Rainfly, so the barometer cannot be read. Turn it on in Settings, Privacy & Security."
        default:
            return live().lastReading.map { "Last reading \($0.formatted(date: .abbreviated, time: .shortened))." } ?? "No overnight reading yet."
        }
    }

    /// Asks for notifications, and reads the barometer once so the system asks for motion
    /// access while the app is on screen rather than in a background refresh, where it cannot.
    static func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        if CMAltimeter.authorizationStatus() == .notDetermined {
            _ = await Barometer().read()
        }
    }

    private static func post(_ message: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Rainfly"
        content.body = message
        content.sound = .default
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "pressure", content: content, trigger: nil))
    }
}

/// A few seconds of barometer readings, averaged.
@MainActor
private final class Barometer {
    private let altimeter = CMAltimeter()
    private var readings: [Double] = []

    func read(for seconds: Double = 3) async -> Double? {
        guard CMAltimeter.isRelativeAltitudeAvailable() else { return nil }
        altimeter.startRelativeAltitudeUpdates(to: .main) { data, _ in
            guard let kPa = data?.pressure.doubleValue else { return }
            MainActor.assumeIsolated { self.readings.append(kPa * 10) }
        }
        try? await Task.sleep(for: .seconds(seconds))
        altimeter.stopRelativeAltitudeUpdates()
        return readings.isEmpty ? nil : readings.reduce(0, +) / Double(readings.count)
    }
}
