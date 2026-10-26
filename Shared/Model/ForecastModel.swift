// ForecastModel.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
import Observation
import WidgetKit

/// The forecast and verdict for the night that matters now, at the trip's camp for that
/// night or else the watch's own position. The cached night shows first; a fetch replaces
/// it when the cache is missing or older than `refreshAge`.
@MainActor
@Observable
final class ForecastModel {
    static let refreshAge: TimeInterval = 2 * 3600
    /// Nights after tonight whose hours fit inside WeatherKit's ten-day forecast.
    static let tripHorizon = 7

    private(set) var night: NightForecast?
    private(set) var verdict: Verdict?
    private(set) var attribution = Attribution.fallback
    private(set) var isRefreshing = false
    private(set) var problem: String?
    private(set) var campName = CampLocation.hereName
    private(set) var camps: Camps
    private(set) var isDownloading = false
    private(set) var downloadReport: String?
    /// Counts the nights saved, so a view reading the cache redraws when it changes.
    private var cacheRevision = 0
    var settings: Settings {
        didSet {
            changed { store.settings = settings }
            sharedChanged()
        }
    }
    var preferences: Preferences {
        didSet {
            changed { store.preferences = preferences }
            if preferences.units != oldValue.units {
                sharedChanged()
            } else if !isApplying {
                sharedStateChanged?()
            }
        }
    }

    /// Called after a change the other device should hear of, the pressure toggle included.
    @ObservationIgnored var sharedStateChanged: (() -> Void)?
    /// Called after a saved camp's night is fetched, so the other device can cache it too.
    @ObservationIgnored var nightFetched: ((NightForecast) -> Void)?
    @ObservationIgnored private var isApplying = false

    @ObservationIgnored private let provider: ForecastProvider
    @ObservationIgnored private let cache: ForecastCache
    @ObservationIgnored private let store: SettingsStore
    @ObservationIgnored private let campStore: Store<Camps>
    @ObservationIgnored private let locate: @MainActor () async throws -> CampLocation

    init(
        provider: ForecastProvider,
        cache: ForecastCache,
        store: SettingsStore,
        campStore: Store<Camps>,
        locate: @escaping @MainActor () async throws -> CampLocation
    ) {
        self.provider = provider
        self.cache = cache
        self.store = store
        self.campStore = campStore
        self.locate = locate
        settings = store.settings
        preferences = store.preferences
        camps = campStore.load() ?? Camps()
    }

    static func live() -> ForecastModel {
        let fix = LocationFix()
        return ForecastModel(provider: WeatherKitProvider(), cache: ForecastCache(), store: SettingsStore(), campStore: .camps) {
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

    /// The night that matters at `now`: last night until pack-by, tonight from then on.
    func nightDate(at now: Date = .now) -> NightDate {
        NightDate.covering(now, packByMinutes: settings.packByMinutes, calendar: .current)
    }

    /// In the background the watch's position comes from the last fetch for Here, since
    /// watchOS gives no fresh location to an app that is off screen.
    func refreshIfStale(now: Date = .now, inBackground: Bool = false) async {
        let date = nightDate(at: now)
        dropPastNights(before: date)
        let name = camps.campName(on: date)
        if name != campName { problem = nil }
        campName = name
        night = cache.night(at: campName, on: date)
        evaluate()
        if let night, now.timeIntervalSince(night.fetchedAt) < Self.refreshAge { return }
        await refresh(now: now, inBackground: inBackground)
    }

    func refresh(now: Date = .now, inBackground: Bool = false) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let date = nightDate(at: now)
        let name = camps.campName(on: date)
        campName = name
        do {
            let camp: CampLocation
            if let saved = camps.camp(named: name) {
                camp = saved
            } else if inBackground, let last = cache.latest(at: name)?.location {
                camp = last
            } else {
                camp = try await locate()
            }
            let fetched = try await fetch(camp, on: date, now: now)
            if name == campName {
                night = fetched
                problem = nil
                evaluate()
            }
        } catch {
            problem = Self.describe(error)
        }
        if attribution == .fallback, let fetched = try? await provider.attribution() {
            attribution = fetched
        }
    }

    /// Shows `name` tonight by planning it for the current night; "Here" clears the plan.
    func show(_ name: String, now: Date = .now) async {
        updateCamps { $0.plan(name, on: nightDate(at: now)) }
        await refreshIfStale(now: now)
    }

    func locateHere() async throws -> CampLocation {
        try await locate()
    }

    func addCamp(_ camp: CampLocation) {
        updateCamps { $0.add(camp) }
    }

    func removeCamp(named name: String) async {
        updateCamps { $0.remove(named: name) }
        if name == campName { await refreshIfStale() }
    }

    func plan(_ name: String, on date: NightDate) async {
        updateCamps { $0.plan(name, on: date) }
        if date == nightDate() { await refreshIfStale() }
    }

    func removeNight(on date: NightDate) async {
        updateCamps { $0.removeNight(on: date) }
        if date == nightDate() { await refreshIfStale() }
    }

    /// The night already on the watch for `tripNight`.
    func cachedNight(_ tripNight: TripNight) -> NightForecast? {
        _ = cacheRevision
        return cache.night(at: tripNight.campName, on: tripNight.date)
    }

    var sharedState: SyncedState {
        SyncedState(camps: camps, settings: settings, units: preferences.units, modifiedAt: store.syncedAt)
    }

    /// Takes the other device's state when it is newer than this one's.
    @discardableResult
    func apply(_ received: SyncedState) async -> Bool {
        guard SyncRules.adopts(received, over: sharedState) else { return false }
        isApplying = true
        camps = received.camps
        campStore.save(camps)
        settings = received.settings
        preferences.units = received.units
        store.syncedAt = received.modifiedAt
        isApplying = false
        await refreshIfStale()
        return true
    }

    /// Caches a night the other device fetched, and shows it if it is the one that matters now.
    func receive(_ received: NightForecast) {
        let date = ForecastCache.date(of: received)
        guard SyncRules.keeps(received, over: cache.night(at: received.location.name, on: date)) else { return }
        cache.save(received)
        cacheRevision += 1
        WidgetCenter.shared.reloadAllTimelines()
        if received.location.name == campName, date == nightDate() {
            night = received
            evaluate()
        }
    }

    /// Fetches every trip night within reach whose forecast is missing or old, so the
    /// trip holds offline.
    func downloadTrip(now: Date = .now) async {
        guard !isDownloading else { return }
        isDownloading = true
        defer { isDownloading = false }
        let tonight = nightDate(at: now)
        dropPastNights(before: tonight)
        let reachable = camps.trip.filter { $0.date.days(since: tonight) <= Self.tripHorizon }
        let due = reachable.filter { tripNight in
            cachedNight(tripNight).map { now.timeIntervalSince($0.fetchedAt) >= Self.refreshAge } ?? true
        }
        var failure: String?
        for tripNight in due {
            guard let camp = camps.camp(named: tripNight.campName) else { continue }
            do {
                _ = try await fetch(camp, on: tripNight.date, now: now)
            } catch {
                failure = Self.describe(error)
            }
        }
        let ready = reachable.filter { cachedNight($0) != nil }.count
        var report = ready == 1 ? "1 night ready." : "\(ready) nights ready."
        if let failure { report += " " + failure }
        if reachable.count < camps.trip.count { report += " Later nights download once they are a week out." }
        downloadReport = report
        await refreshIfStale(now: now)
    }

    private func fetch(_ camp: CampLocation, on date: NightDate, now: Date) async throws -> NightForecast {
        let evening = date.start(in: NightWindow.localCalendar(for: camp))
        let fetched = try await provider.night(at: camp, evening: evening)
        cache.save(fetched, now: now)
        cacheRevision += 1
        WidgetCenter.shared.reloadAllTimelines()
        if SyncRules.sends(fetched) { nightFetched?(fetched) }
        return fetched
    }

    private static func describe(_ error: Error) -> String {
        (error as? ForecastError)?.localizedDescription ?? "Couldn't reach the weather service."
    }

    private func dropPastNights(before date: NightDate) {
        if camps.trip.contains(where: { $0.date < date }) {
            updateCamps(shared: false) { $0.removeNights(before: date) }
        }
    }

    /// Dropping past nights is not shared, since both devices do it on their own.
    private func updateCamps(shared: Bool = true, _ change: (inout Camps) -> Void) {
        change(&camps)
        campStore.save(camps)
        WidgetCenter.shared.reloadAllTimelines()
        if shared { sharedChanged() }
    }

    private func sharedChanged() {
        guard !isApplying else { return }
        store.syncedAt = .now
        sharedStateChanged?()
    }

    /// Saves a change, re-decides and redraws the complication, which reads the same store.
    private func changed(_ save: () -> Void) {
        save()
        evaluate()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func evaluate() {
        verdict = night.map { FlyEngine.evaluate($0, settings: settings) }
    }
}
