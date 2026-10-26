// CloudKit.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Crypto
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// CloudKit Web Services for the app's container, signed with a server-to-server key. The key
/// acts as the iCloud user who made it, so that user needs a security role that reads
/// DiaryNight; the public cannot.
struct CloudKit {
    static let container = "iCloud.com.excelano.zeltwetter"

    let keyID: String
    let key: P256.Signing.PrivateKey
    let environment: String

    /// Every DiaryNight record, following the continuation marker page by page.
    func diaryNights() async throws -> [CloudRecord] {
        var records: [CloudRecord] = []
        var marker: String?
        repeat {
            var body: [String: Any] = ["query": ["recordType": "DiaryNight"], "resultsLimit": 200]
            if let marker { body["continuationMarker"] = marker }
            let page: QueryPage = try await post("records/query", body: body)
            records += page.records
            marker = page.continuationMarker
        } while marker != nil
        return records
    }

    private func post<Response: Decodable>(_ operation: String, body: [String: Any]) async throws -> Response {
        let subpath = "/database/1/\(Self.container)/\(environment)/public/\(operation)"
        let data = try JSONSerialization.data(withJSONObject: body)
        let date = ISO8601DateFormatter().string(from: .now)
        let digest = Data(SHA256.hash(data: data)).base64EncodedString()
        let signature = try key.signature(for: Data("\(date):\(digest):\(subpath)".utf8)).derRepresentation.base64EncodedString()

        var request = URLRequest(url: URL(string: "https://api.apple-cloudkit.com" + subpath)!)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(keyID, forHTTPHeaderField: "X-Apple-CloudKit-Request-KeyID")
        request.setValue(date, forHTTPHeaderField: "X-Apple-CloudKit-Request-ISO8601Date")
        request.setValue(signature, forHTTPHeaderField: "X-Apple-CloudKit-Request-SignatureV1")
        let (answer, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw ToolError("CloudKit answered \(status): \(String(decoding: answer, as: UTF8.self))")
        }
        return try JSONDecoder().decode(Response.self, from: answer)
    }
}

struct QueryPage: Decodable {
    let records: [CloudRecord]
    let continuationMarker: String?
}

/// A record as CloudKit Web Services returns it: each field a value with its type.
struct CloudRecord: Codable {
    let recordName: String
    let fields: [String: Field]

    struct Field: Codable {
        let value: Value
    }

    enum Value: Codable {
        case string(String)
        case number(Double)

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let number = try? container.decode(Double.self) {
                self = .number(number)
            } else {
                self = .string(try container.decode(String.self))
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .string(let text): try container.encode(text)
            case .number(let number): try container.encode(number)
            }
        }
    }

    func string(_ name: String) -> String? {
        if case .string(let text)? = fields[name]?.value { return text }
        return nil
    }

    func number(_ name: String) -> Double? {
        if case .number(let number)? = fields[name]?.value { return number }
        return nil
    }
}

struct ToolError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
