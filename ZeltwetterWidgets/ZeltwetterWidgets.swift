// ZeltwetterWidgets.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI
import WidgetKit

@main
struct ZeltwetterWidgets: WidgetBundle {
    var body: some Widget {
        VerdictWidget()
    }
}

struct VerdictEntry: TimelineEntry {
    let date: Date
    let face: ComplicationFace
}

/// Reads the night the app cached; the app reloads the timeline whenever it saves one.
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
        return ComplicationTimeline.entries(now: now, settings: settings, units: store.preferences.units) { date in
            cache.night(at: CampLocation.hereName, covering: date, packByMinutes: settings.packByMinutes)
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
        .configurationDisplayName("Rain fly")
        .description("Tonight's rain fly verdict, and when the tent will be dry.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}

struct VerdictWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: VerdictEntry

    private var face: ComplicationFace { entry.face }

    var body: some View {
        switch family {
        case .accessoryCorner:
            glyph
                .font(.title2)
                .widgetLabel(face.dryTime.map { "Dry \($0)" } ?? face.headline)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Label { Text(face.headline) } icon: { glyph }
                    .font(.headline)
                Text(face.detail)
                    .font(.footnote)
                if let fetchedAt = face.fetchedAt {
                    Text(VerdictText.age(since: fetchedAt, at: entry.date))
                        .font(.caption2)
                        .foregroundStyle(ageColor(fetchedAt))
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
                    glyph.font(.title2)
                }
            }
        }
    }

    @ViewBuilder
    private var glyph: some View {
        switch face.flyOn {
        case true?: Image(systemName: "tent.fill").foregroundStyle(Self.green)
        case false?: Image(systemName: "tent")
        case nil: Image(systemName: "tent").foregroundStyle(.secondary)
        }
    }

    private func ageColor(_ fetchedAt: Date) -> Color {
        switch VerdictText.staleness(since: fetchedAt, at: entry.date) {
        case .fresh: .secondary
        case .aging: .orange
        case .stale: .red
        }
    }

    // The app's accent color.
    private static let green = Color(red: 0x3E / 255, green: 0x8E / 255, blue: 0x6A / 255)
}
