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
}

struct VerdictProvider: TimelineProvider {
    func placeholder(in context: Context) -> VerdictEntry {
        VerdictEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (VerdictEntry) -> Void) {
        completion(VerdictEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VerdictEntry>) -> Void) {
        completion(Timeline(entries: [VerdictEntry(date: .now)], policy: .never))
    }
}

struct VerdictWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Verdict", provider: VerdictProvider()) { _ in
            Image(systemName: "tent")
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Zeltwetter")
        .description("Tonight's rain fly verdict.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}
