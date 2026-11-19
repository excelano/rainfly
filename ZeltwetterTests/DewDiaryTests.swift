// DewDiaryTests.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
import Testing
@testable import Zeltwetter_Watch_App

private typealias F = Fixture

/// A clear, calm night whose closest spread is `spread`, at a camp of its own so each one is
/// a separate night of the diary.
private func night(_ camp: String, spread: Double, fetchedAt: Date = F.at(0, 18)) -> NightForecast {
    let base = F.night { F.hour($0, temp: 12, dewPoint: 12 - spread, wind: 1) }
    let location = CampLocation(name: camp, latitude: F.camp.latitude, longitude: F.camp.longitude, timeZoneID: F.camp.timeZoneID)
    return NightForecast(location: location, fetchedAt: fetchedAt, sunset: base.sunset, sunrise: base.sunrise, hours: base.hours)
}

/// Each night's call is sealed from its forecast, fetched before the anchor.
private func diary(_ nights: [(NightForecast, DewObservation.Kind, openSky: Bool)]) -> DewDiary {
    var diary = DewDiary()
    for (forecast, kind, openSky) in nights {
        diary.record(forecast)
        diary.setCall(NightCall.seal(forecast, settings: Settings())!)
        diary.observe(DewObservation(kind: kind, openSky: openSky, at: forecast.sunrise), campName: forecast.location.name, on: ForecastCache.date(of: forecast))
    }
    return diary
}

private let metric = DisplayUnits(fahrenheit: false, mph: false)

struct DewDiaryRecordingTests {
    @Test func eachFetchIsKeptOnceUnderItsNight() {
        var diary = DewDiary()
        let forecast = F.night()
        diary.record(forecast)
        diary.record(forecast)
        diary.record(NightForecast(location: forecast.location, fetchedAt: forecast.fetchedAt.addingTimeInterval(3600), sunset: forecast.sunset, sunrise: forecast.sunrise, hours: forecast.hours))
        #expect(diary.nights.count == 1)
        #expect(diary.nights[0].forecasts.count == 2)
        #expect(diary.nights[0].date == ForecastCache.date(of: forecast))
    }

    @Test func aRightForecastTakesTheLastAnswersSpot() {
        var diary = DewDiary()
        let first = F.night()
        let second = NightForecast(
            location: first.location, fetchedAt: first.fetchedAt.addingTimeInterval(86_400),
            sunset: first.sunset.addingTimeInterval(86_400), sunrise: first.sunrise.addingTimeInterval(86_400), hours: []
        )
        diary.record(first)
        diary.record(second)
        let firstDate = ForecastCache.date(of: first), secondDate = ForecastCache.date(of: second)
        #expect(diary.lastOpenSky(before: firstDate))
        diary.observe(DewObservation(kind: .dry, openSky: false, at: first.sunrise), campName: first.location.name, on: firstDate)
        #expect(!diary.lastOpenSky(before: secondDate))
        #expect(diary.lastOpenSky(before: firstDate))
    }

    @Test func theMorningAsksOnceAboutTheNightsCamp() {
        var diary = DewDiary()
        let forecast = F.night()
        diary.record(forecast)
        let camp = { (_: NightDate) in forecast.location.name }
        #expect(diary.awaitingObservation(now: forecast.sunrise.addingTimeInterval(-DewDiary.earlyAnswer - 60), campName: camp) == nil)
        #expect(diary.awaitingObservation(now: forecast.sunrise.addingTimeInterval(-DewDiary.earlyAnswer + 60), campName: camp) != nil)
        let asked = diary.awaitingObservation(now: forecast.sunrise.addingTimeInterval(3600), campName: camp)
        #expect(asked?.campName == forecast.location.name)
        #expect(diary.awaitingObservation(now: forecast.sunrise.addingTimeInterval(3600)) { _ in "Elsewhere" } == nil)
        #expect(diary.awaitingObservation(now: forecast.sunrise.addingTimeInterval(DewDiary.answerWindow + 60), campName: camp) == nil)

        diary.observe(DewObservation(kind: .notChecked, openSky: true, at: forecast.sunrise), campName: forecast.location.name, on: asked!.date)
        #expect(diary.awaitingObservation(now: forecast.sunrise.addingTimeInterval(3600), campName: camp) == nil)
    }

    @Test func historyIsFetchedAfterTheNightAndAgainOnceSettled() {
        var diary = DewDiary()
        let forecast = F.night()
        diary.record(forecast)
        let date = diary.nights[0].date
        let fetched = { (after: TimeInterval) in
            NightForecast(location: forecast.location, fetchedAt: forecast.sunrise.addingTimeInterval(after), sunset: forecast.sunset, sunrise: forecast.sunrise, hours: forecast.hours)
        }
        #expect(diary.needingHistory(now: forecast.sunrise).isEmpty)
        #expect(diary.needingHistory(now: forecast.sunrise.addingTimeInterval(DewDiary.historyDelay + 60)).count == 1)
        diary.setHistory(fetched(3 * 3600), campName: forecast.location.name, on: date)
        #expect(diary.needingHistory(now: forecast.sunrise.addingTimeInterval(4 * 3600)).count == 1)
        diary.setHistory(fetched(DewDiary.settledAfter + 60), campName: forecast.location.name, on: date)
        #expect(diary.needingHistory(now: forecast.sunrise.addingTimeInterval(DewDiary.settledAfter + 3600)).isEmpty)

        var unfetched = DewDiary()
        unfetched.record(forecast)
        #expect(unfetched.needingHistory(now: forecast.sunrise.addingTimeInterval(DewDiary.historyReach + 60)).isEmpty)
    }

    @Test func aNightCanBeRemoved() {
        var diary = diary([(night("A", spread: 2), .wet, true), (night("B", spread: 8), .dry, true)])
        diary.remove(campName: "A", on: diary.nights[0].date)
        #expect(diary.nights.map(\.campName) == ["B"])
    }
}

struct DewDiaryJudgingTests {
    @Test func theCallIsTheOneJudgedWhateverElseWasFetched() {
        var diary = DewDiary()
        diary.record(night("A", spread: 8, fetchedAt: F.at(0, 17)))
        diary.record(night("A", spread: 2, fetchedAt: F.at(0, 21, 30)))
        diary.record(night("A", spread: 8, fetchedAt: F.at(0, 23)))
        #expect(diary.nights[0].judgement == nil)
        diary.setCall(NightCall.seal(night("A", spread: 2, fetchedAt: F.at(0, 21, 30)), settings: Settings())!)
        #expect(diary.nights[0].judgement?.predicted == true)
        #expect(diary.nights[0].forecasts.count == 3)
    }

    @Test func aCallFromALaterForecastReplacesAnEarlierOne() {
        var diary = DewDiary()
        diary.record(night("A", spread: 8, fetchedAt: F.at(0, 17)))
        let early = NightCall.seal(night("A", spread: 8, fetchedAt: F.at(0, 17)), settings: Settings())!
        let late = NightCall.seal(night("A", spread: 2, fetchedAt: F.at(0, 21, 30)), settings: Settings())!
        diary.setCall(late)
        diary.setCall(early)
        #expect(diary.nights[0].call == late)
    }

    @Test func aNightWithNoCallIsNotScored() {
        var diary = DewDiary()
        let late = night("A", spread: 2, fetchedAt: F.at(1, 0, 58))
        diary.record(late)
        diary.observe(DewObservation(kind: .wet, openSky: true, at: late.sunrise), campName: "A", on: diary.nights[0].date)
        #expect(diary.nights[0].judgement == nil)
        #expect(diary.tally == DiaryTally())
        #expect(diary.openSkyCounts.wet == 0)
    }

    @Test func outcomesFollowWhatWasFound() {
        let diary = diary([
            (night("caught", spread: 2), .wet, true),
            (night("frost", spread: 2), .frost, true),
            (night("clear", spread: 8), .dry, true),
            (night("missed", spread: 8), .wet, true),
            (night("alarm", spread: 2), .dry, true),
            (night("light", spread: 2), .lightDew, true),
            (night("light dry", spread: 8), .lightDew, true),
            (night("rain", spread: 2), .rain, true),
        ])
        let outcome = { (camp: String) in diary.nights.first { $0.campName == camp }?.judgement?.outcome }
        #expect(outcome("caught") == .caught)
        #expect(outcome("frost") == .caught)
        #expect(outcome("clear") == .clear)
        #expect(outcome("missed") == .missed)
        #expect(outcome("alarm") == .falseAlarm)
        #expect(outcome("light") == nil)
        #expect(outcome("rain") == nil)
        #expect(diary.tally == DiaryTally(caught: 2, clear: 1, missed: 1, falseAlarms: 1, lightDew: 2, lightDewFlagged: 1))
    }

    @Test func aRainForecastIsKeptBesideTheDewCall() {
        let judgement = diary([(F.night { F.hour($0, chance: 0.9) }, .notChecked, true)]).nights[0].judgement
        #expect(judgement?.rain?.trigger == .rain)
        #expect(judgement?.predicted == false)
        #expect(diary([(night("dew", spread: 2), .wet, true)]).nights[0].judgement?.rain == nil)
    }

    @Test func theHistoryPlaysNoPartInTheJudgement() {
        var missed = diary([(night("A", spread: 8), .wet, true)])
        let judged = missed.nights[0].judgement
        missed.setHistory(night("A", spread: 2), campName: "A", on: missed.nights[0].date)
        #expect(missed.nights[0].judgement == judged)
        #expect(judged?.outcome == .missed)
    }

    @Test func aCallIsJudgedByTheSettingsItWasSealedWith() {
        var wide = Settings()
        wide.dewSpreadC = 5
        var diary = DewDiary()
        let forecast = night("A", spread: 4)
        diary.record(forecast)
        diary.setCall(NightCall.seal(forecast, settings: wide)!)
        #expect(diary.nights[0].judgement?.predicted == true)
    }
}

struct DewDiarySuggestionTests {
    private let nearMisses: [(NightForecast, DewObservation.Kind, openSky: Bool)] = [
        (night("wet 3.5 a", spread: 3.5), .wet, true),
        (night("wet 3.5 b", spread: 3.5), .wet, true),
        (night("wet 2", spread: 2), .wet, true),
        (night("dry 6 a", spread: 6.5), .dry, true),
        (night("dry 6 b", spread: 6.5), .dry, true),
    ]

    @Test func suggestsTheNearestSpreadThatCatchesTheWetNights() throws {
        let suggestion = try #require(diary(nearMisses).suggestedDewSpread(settings: Settings(), units: metric))
        #expect(suggestion.suggested == SpreadScore(spreadC: 3.5, caught: 3, falseAlarms: 0))
        #expect(suggestion.current == SpreadScore(spreadC: 3, caught: 1, falseAlarms: 0))
        #expect(suggestion.wetNights == 3)
    }

    @Test func nightsUnderTreesAreLeftOut() throws {
        let suggestion = try #require(diary(nearMisses + [(night("trees", spread: 5), .wet, false)]).suggestedDewSpread(settings: Settings(), units: metric))
        #expect(suggestion.suggested.spreadC == 3.5)
    }

    @Test func catchingComesBeforeFalseAlarms() throws {
        let suggestion = try #require(diary(nearMisses + [(night("dry 3.5", spread: 3.5), .dry, true)]).suggestedDewSpread(settings: Settings(), units: metric))
        #expect(suggestion.suggested == SpreadScore(spreadC: 3.5, caught: 3, falseAlarms: 1))
    }

    @Test func noSuggestionWithoutEnoughOfBoth() {
        #expect(diary(Array(nearMisses.prefix(4))).suggestedDewSpread(settings: Settings(), units: metric) == nil)
        let allWet = nearMisses.map { ($0.0, DewObservation.Kind.wet, $0.openSky) }
        #expect(diary(allWet).suggestedDewSpread(settings: Settings(), units: metric) == nil)
    }

    @Test func progressCountsOpenSkyNightsOfEachKind() {
        let some = diary(Array(nearMisses.prefix(4)) + [(night("trees", spread: 5), .wet, false)])
        #expect(some.openSkyCounts.wet + some.openSkyCounts.dry == 4)
        #expect(!some.canSuggest)
        #expect(diary(nearMisses).canSuggest)
    }

    @Test func noSuggestionWhenTheCurrentSpreadIsBest() {
        var settings = Settings()
        settings.dewSpreadC = 3.5
        #expect(diary(nearMisses).suggestedDewSpread(settings: settings, units: metric) == nil)
    }
}

#if DEBUG
struct DewDiaryReportTests {
    @Test func theReportComparesTheForecastWithTheHistory() {
        var diary = diary([(night("A", spread: 8), .wet, true)])
        diary.setHistory(night("A", spread: 2), campName: "A", on: diary.nights[0].date)
        let rows = diary.report.split(separator: "\n").map { $0.split(separator: ",", omittingEmptySubsequences: false).map(String.init) }
        #expect(rows.count == 2)
        let row = Dictionary(uniqueKeysWithValues: zip(rows[0], rows[1]))
        #expect(row["found"] == "wet")
        #expect(row["open_sky"] == "yes")
        #expect(row["forecast_wet"] == "dry")
        #expect(row["history_wet"] == "dew")
    }
}
#endif

struct SharedNightTests {
    private let id = UUID(uuidString: "6F1A2B3C-0000-4000-8000-000000000001")!

    private func answered(_ kind: DewObservation.Kind, at: Date = F.at(1, 7)) -> DiaryNight {
        let base = night("Mom's place", spread: 2)
        let precise = CampLocation(name: base.location.name, latitude: 39.93891, longitude: -105.61063, timeZoneID: base.location.timeZoneID)
        let forecast = NightForecast(location: precise, fetchedAt: base.fetchedAt, sunset: base.sunset, sunrise: base.sunrise, hours: base.hours)
        var diary = DewDiary()
        diary.record(forecast)
        diary.setCall(NightCall.seal(forecast, settings: Settings())!)
        diary.observe(DewObservation(kind: kind, openSky: true, at: at), campName: precise.name, on: diary.nights[0].date)
        return diary.nights[0]
    }

    @Test func aSharedNightIsRoundedAndCarriesNoName() throws {
        let shared = try #require(SharedNight(answered(.wet), diaryID: id, appVersion: "1.0.1"))
        #expect(shared.latitude == 39.9)
        #expect(shared.longitude == -105.6)
        let payload = String(decoding: try SharedNight.encoder.encode(shared.forecast), as: UTF8.self)
        #expect(!payload.contains("Mom"))
        #expect(!payload.contains("39.93"))
        #expect(shared.recordName == "6f1a2b3c-0000-4000-8000-000000000001_2026-07-01_39.9_-105.6")
        #expect(SharedNight(answered(.wet), diaryID: id, appVersion: "1.0.2")?.recordName == shared.recordName)
    }

    @Test func nightsWithoutAnAnswerAreNotShared() {
        #expect(SharedNight(answered(.notChecked), diaryID: id, appVersion: "1") == nil)
        var unanswered = answered(.wet)
        unanswered.observation = nil
        #expect(SharedNight(unanswered, diaryID: id, appVersion: "1") == nil)
    }

    @Test func aNightIsResentOnlyWhenItChanges() {
        var diary = DewDiary(nights: [answered(.wet, at: F.at(1, 7))])
        let date = diary.nights[0].date
        #expect(diary.needingShare().count == 1)
        diary.markShared(SharedMark(recordName: "r", at: F.at(1, 8)), campName: diary.nights[0].campName, on: date)
        #expect(diary.needingShare().isEmpty)
        diary.setHistory(NightForecast(location: F.camp, fetchedAt: F.at(1, 20), sunset: F.sunset, sunrise: F.sunrise, hours: []), campName: diary.nights[0].campName, on: date)
        #expect(diary.needingShare().count == 1)
        diary.markShared(SharedMark(recordName: "r", at: F.at(1, 21)), campName: diary.nights[0].campName, on: date)
        diary.observe(DewObservation(kind: .dry, openSky: true, at: F.at(1, 22)), campName: diary.nights[0].campName, on: date)
        #expect(diary.needingShare().count == 1)
        diary.observe(DewObservation(kind: .notChecked, openSky: true, at: F.at(1, 23)), campName: diary.nights[0].campName, on: date)
        #expect(diary.needingShare().isEmpty)
    }
}
