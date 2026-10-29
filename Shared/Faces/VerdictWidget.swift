// VerdictWidget.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI
import WidgetKit

struct VerdictEntry: TimelineEntry {
    let date: Date
    let face: ComplicationFace
}

/// Reads the night the app cached for each night's camp; the app reloads the timeline
/// whenever it saves a night or changes the trip.
struct VerdictProvider: TimelineProvider {
    func placeholder(in context: Context) -> VerdictEntry {
        VerdictEntry(date: .now, face: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (VerdictEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entries(now: .now)[0])
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VerdictEntry>) -> Void) {
        completion(Timeline(entries: entries(now: .now), policy: .atEnd))
    }

    private func entries(now: Date) -> [VerdictEntry] {
        let store = SettingsStore()
        let settings = store.settings
        let cache = ForecastCache()
        let camps = Store.camps.load() ?? Camps()
        return ComplicationTimeline.entries(now: now, settings: settings, units: store.preferences.units) { date in
            let night = NightDate.covering(date, packByMinutes: settings.packByMinutes, calendar: .current)
            return cache.night(at: camps.campName(on: night), on: night)
        }
        .map { VerdictEntry(date: $0.date, face: $0.face) }
    }
}

struct VerdictWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Verdict", provider: VerdictProvider()) { entry in
            VerdictWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Rainfly")
        .description("Tonight's rainfly verdict, and when the tent will be dry.")
        .supportedFamilies(Self.families)
    }

    #if os(watchOS)
    private static let families: [WidgetFamily] = [.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline]
    #else
    private static let families: [WidgetFamily] = [.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline]
    #endif
}

struct VerdictWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: VerdictEntry

    private var face: ComplicationFace { entry.face }

    var body: some View {
        switch family {
        #if os(watchOS)
        case .accessoryCorner:
            glyph
                .frame(width: 26, height: 26)
                .widgetLabel(face.dryTime.map { "Dry \($0)" } ?? face.headline)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(face.headline). \(face.detail)")
        #else
        case .systemSmall:
            VStack(alignment: .leading, spacing: 2) {
                glyph.frame(width: 44, height: 44)
                Spacer(minLength: 0)
                Text(face.headline)
                    .font(.headline)
                Text(face.detail)
                    .font(.caption)
                    .lineLimit(2)
                if let camp = face.camp {
                    Text(camp)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        case .systemMedium:
            HStack(spacing: 16) {
                glyph.frame(width: 72, height: 72)
                VStack(alignment: .leading, spacing: 2) {
                    Text(face.headline)
                        .font(.title3.bold())
                    Text(face.detail)
                        .font(.subheadline)
                        .lineLimit(2)
                    ForEach(face.notes, id: \.self) { note in
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    footer
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        #endif
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Label { Text(face.headline) } icon: { glyph.frame(width: 20, height: 20) }
                    .font(.headline)
                Text(face.detail)
                    .font(.footnote)
                if let fetchedAt = face.fetchedAt {
                    Text(VerdictText.age(since: fetchedAt, at: entry.date))
                        .font(.caption2)
                        .foregroundStyle(VerdictText.staleness(since: fetchedAt, at: entry.date).color)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .accessoryInline:
            Text(face.inline)
        default:
            ZStack {
                AccessoryWidgetBackground()
                if let dryTime = face.dryTime {
                    VStack(spacing: 0) {
                        Text("DRY").font(.system(size: 9, weight: .semibold))
                        Text(dryTime).font(.system(.body, design: .rounded).weight(.semibold))
                    }
                } else {
                    glyph.frame(width: 30, height: 30)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(face.headline). \(face.detail)")
        }
    }

    /// The camp and the forecast's age, under the medium widget's text.
    private var footer: some View {
        let parts = [face.camp, face.fetchedAt.map { VerdictText.age(since: $0, at: entry.date) }].compactMap { $0 }
        return Text(parts.joined(separator: " · "))
            .font(.caption2)
            .foregroundStyle(face.fetchedAt.map { VerdictText.staleness(since: $0, at: entry.date).color } ?? .secondary)
            .lineLimit(1)
    }

    @ViewBuilder
    private var glyph: some View {
        switch face.flyOn {
        case true?: TentGlyph(flyOn: true).foregroundStyle(Self.green)
        case false?: TentGlyph(flyOn: false)
        case nil: TentGlyph(flyOn: false).foregroundStyle(.secondary)
        }
    }

    // The app's accent color.
    private static let green = Color(red: 0x3E / 255, green: 0x8E / 255, blue: 0x6A / 255)
}
