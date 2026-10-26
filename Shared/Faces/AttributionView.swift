// AttributionView.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

/// The Apple Weather mark and the legal link WeatherKit requires. Offline, the mark falls
/// back to text.
struct AttributionView: View {
    let attribution: Attribution
    var markHeight: CGFloat = 14

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            AsyncImage(url: attribution.markURL) { image in
                image.resizable().scaledToFit().frame(height: markHeight)
            } placeholder: {
                Text("\u{F8FF} Weather").font(.footnote)
            }
            Link("Data sources", destination: attribution.legalURL)
                .font(.footnote)
        }
    }
}
