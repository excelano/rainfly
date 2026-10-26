// DiaryUploader.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import CloudKit
import Foundation

/// Sends shared diary nights to the public database of Excelano's CloudKit container, and
/// deletes them. The database's security roles let anyone signed in to iCloud create a
/// record and only its creator read, change or delete it.
struct DiaryUploader {
    static let containerID = "iCloud.com.excelano.zeltwetter"
    static let recordType = "DiaryNight"

    private var database: CKDatabase { CKContainer(identifier: Self.containerID).publicCloudDatabase }

    /// Saves `nights`, replacing earlier copies, and deletes `replaced`, the copies a new diary
    /// ID has made stale.
    func send(_ nights: [SharedNight], deleting replaced: [String]) async throws {
        let records = try nights.map(Self.record)
        let deleting = replaced.map { CKRecord.ID(recordName: $0) }
        let (saved, deleted) = try await database.modifyRecords(saving: records, deleting: deleting, savePolicy: .allKeys)
        for result in saved.values { _ = try result.get() }
        for result in deleted.values { try result.get() }
    }

    func delete(_ recordNames: [String]) async throws {
        guard !recordNames.isEmpty else { return }
        let (_, deleted) = try await database.modifyRecords(saving: [], deleting: recordNames.map { CKRecord.ID(recordName: $0) })
        for result in deleted.values {
            if case .failure(let error as CKError) = result, error.code == .unknownItem { continue }
            try result.get()
        }
    }

    private static func record(_ night: SharedNight) throws -> CKRecord {
        let record = CKRecord(recordType: recordType, recordID: CKRecord.ID(recordName: night.recordName))
        record["diary"] = night.diaryID.uuidString.lowercased()
        record["night"] = night.night
        record["latitude"] = night.latitude
        record["longitude"] = night.longitude
        record["timeZone"] = night.timeZoneID
        record["found"] = night.found.rawValue
        record["openSky"] = night.openSky ? 1 : 0
        record["forecast"] = try json(night.forecast)
        record["history"] = try night.history.map(json)
        record["settings"] = try json(night.settings)
        record["appVersion"] = night.appVersion
        return record
    }

    private static func json<Value: Encodable>(_ value: Value) throws -> String {
        String(decoding: try SharedNight.encoder.encode(value), as: UTF8.self)
    }

    /// Words for the diary screen when sending fails.
    static func describe(_ error: Error) -> String {
        switch (error as? CKError)?.code {
        case .notAuthenticated?: "Sign in to iCloud in the Settings app to share."
        case .networkUnavailable?, .networkFailure?, .serviceUnavailable?, .requestRateLimited?, .zoneBusy?:
            "Waiting for a connection; nights will be sent then."
        case .quotaExceeded?: "iCloud refused the nights for now; they will be sent later."
        default: "Couldn't share: \(error.localizedDescription)"
        }
    }
}
