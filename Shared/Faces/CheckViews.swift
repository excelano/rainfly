// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

struct CheckRow: View {
    let trigger: Trigger
    let text: VerdictText

    var body: some View {
        let firing = text.verdict.firing(trigger)
        HStack(spacing: 10) {
            CheckIcon(trigger: trigger, expected: firing != nil)
            VStack(alignment: .leading, spacing: 2) {
                Text(firing == nil ? text.clearName(trigger) : VerdictText.name(trigger))
                    .foregroundStyle(firing == nil ? .secondary : .primary)
                Text(text.summary(trigger))
                    .font(Self.detailFont)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if let firing {
                Text(text.clock(firing.at))
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(firing == nil ? text.clearName(trigger) : VerdictText.name(trigger))
        .accessibilityValue([firing.map { "Expected at \(text.clock($0.at))" }, text.summary(trigger)].compactMap { $0 }.joined(separator: ", "))
    }

    #if os(watchOS)
    private static let detailFont = Font.caption2
    #else
    private static let detailFont = Font.footnote
    #endif
}

struct CheckIcon: View {
    let trigger: Trigger
    let expected: Bool

    var body: some View {
        Image(systemName: VerdictText.symbol(trigger))
            .symbolVariant(expected ? .fill : .none)
            .symbolRenderingMode(expected ? .multicolor : .monochrome)
            .foregroundStyle(expected ? Color.accentColor : .secondary)
            .font(.title3)
            .frame(width: 30)
            .accessibilityHidden(true)
    }
}

struct CheckDetail<Thresholds: View>: View {
    let trigger: Trigger
    let text: VerdictText
    @ViewBuilder var thresholds: Thresholds

    var body: some View {
        List {
            Section {
                CheckRow(trigger: trigger, text: text)
            }
            Section("Why it matters") {
                Text(VerdictText.why(trigger))
            }
            Section("When it puts the rainfly on") {
                Text(text.rule(trigger))
                if trigger != .storm {
                    NavigationLink("Change the thresholds") {
                        thresholds
                    }
                }
            }
        }
        .navigationTitle(VerdictText.name(trigger))
    }
}
