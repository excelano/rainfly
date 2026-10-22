// ForecastModel.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
import Observation
import WidgetKit

/// Tonight's forecast and verdict for the watch's own position. The cached night shows
/// first; a fetch replaces it when the cache is missing or older than `refreshAge`.
@MainActor
@Observable
final class ForecastModel {
    static let refreshAge: TimeInterval = 2 * 3600

    private(set) var night: NightForecast?
    private(set) var verdict: Verdict?
    private(set) var attribution = Attribution.fallback
    private(set) var isRefreshing = false
    private(set) var problem: String?
    var settings = Settings() {
        didSet { evaluate() }
    }

    @ObservationIgnored private let provider: ForecastProvider
    @ObservationIgnored private let cache: ForecastCache
    @ObservationIgnored private let locate: @MainActor () async throws -> CampLocation

    init(provider: ForecastProvider, cache: ForecastCache, locate: @escaping @MainActor () async throws -> CampLocation) {
        self.provider = provider
        self.cache = cache
        self.locate = locate
    }

    static func live() -> ForecastModel {
        let fix = LocationFix()
        return ForecastModel(provider: WeatherKitProvider(), cache: ForecastCache()) {
            let location = try await fix.current()
            return CampLocation(
                name: CampLocation.hereName,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                timeZoneID: TimeZone.current.identifier
            )
        }
    }

    var window: NightWindow? {
        night.map { NightWindow($0, packByMinutes: settings.packByMinutes) }
    }

    func refreshIfStale(now: Date = .now) async {
        night = cache.night(at: CampLocation.hereName, covering: now, packByMinutes: settings.packByMinutes)
        evaluate()
        if let night, now.timeIntervalSince(night.fetchedAt) < Self.refreshAge { return }
        await refresh(now: now)
    }

    func refresh(now: Date = .now) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let camp = try await locate()
            let fetched = try await provider.night(at: camp, evening: evening(at: now))
            cache.save(fetched, now: now)
            WidgetCenter.shared.reloadAllTimelines()
            night = fetched
            problem = nil
            evaluate()
        } catch let error as ForecastError {
            problem = error.localizedDescription
        } catch {
            problem = "Couldn't reach the weather service."
        }
        if attribution == .fallback, let fetched = try? await provider.attribution() {
            attribution = fetched
        }
    }

    private func evening(at now: Date) -> Date {
        NightWindow.evening(at: now, packByMinutes: settings.packByMinutes, calendar: .current)
    }

    private func evaluate() {
        verdict = night.map { FlyEngine.evaluate($0, settings: settings) }
    }
}
