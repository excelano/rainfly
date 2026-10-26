// main.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Crypto
import Foundation

let usage = """
Usage: dewdiary pull [--production] [--out <dir>]

Reads every dew diary night shared with Excelano from the CloudKit container
iCloud.com.excelano.zeltwetter, writes <dir>/nights.json (the records as CloudKit returned
them) and <dir>/nights.csv (a row a night, judged by the app's own engine with the
thresholds the camper had set), and prints how each dew spread would have done on the
open-sky nights, on the forecasts and on the history.

The development environment is read unless --production is given. The server-to-server
key is ~/.config/zeltwetter/cloudkit-key.pem and its key ID ~/.config/zeltwetter/cloudkit-key-id.
<dir> defaults to the current directory.
"""

@main
struct DewDiaryTool {
    static func main() async {
        do {
            try await run(Array(CommandLine.arguments.dropFirst()))
        } catch {
            FileHandle.standardError.write(Data("dewdiary: \(error)\n".utf8))
            exit(1)
        }
    }

    static func run(_ arguments: [String]) async throws {
        guard arguments.first == "pull" else {
            print(usage)
            if arguments.isEmpty || ["-h", "--help"].contains(arguments.first) { return }
            throw ToolError("unknown command \(arguments.first!)")
        }
        var environment = "development"
        var out = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        var rest = arguments.dropFirst()
        while let argument = rest.popFirst() {
            switch argument {
            case "--production": environment = "production"
            case "--out":
                guard let dir = rest.popFirst() else { throw ToolError("--out needs a directory") }
                out = URL(fileURLWithPath: dir)
            default: throw ToolError("unknown argument \(argument)")
            }
        }

        let config = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".config/zeltwetter")
        let keyID = try String(contentsOf: config.appending(path: "cloudkit-key-id"), encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        let key = try P256.Signing.PrivateKey(pemRepresentation: String(contentsOf: config.appending(path: "cloudkit-key.pem"), encoding: .utf8))
        let records = try await CloudKit(keyID: keyID, key: key, environment: environment).diaryNights()

        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(records).write(to: out.appending(path: "nights.json"))
        let nights = records.compactMap(Night.init)
        try Report.csv(nights).write(to: out.appending(path: "nights.csv"), atomically: true, encoding: .utf8)

        let diaries = Set(nights.map(\.diary)).count
        print("\(records.count) records from \(diaries == 1 ? "1 diary" : "\(diaries) diaries") in \(environment), written to \(out.path)")
        if records.count > nights.count { print("\(records.count - nights.count) records could not be read and are only in nights.json") }
        print(Report.sweep(nights))
    }
}
