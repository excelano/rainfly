// TentGlyph.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

/// The verdict as a tent: with the fly pitched over it, or bare under the open sky.
/// Drawn as shapes so it scales and tints the same in the app and in every complication.
struct TentGlyph: View {
    let flyOn: Bool

    var body: some View {
        ZStack {
            InnerTent()
                .fill(style: FillStyle(eoFill: true))
                .opacity(flyOn ? 0.55 : 1)
            if flyOn {
                Fly()
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// The A-frame body with its door cut out.
private struct InnerTent: Shape {
    func path(in rect: CGRect) -> Path {
        let point = { (x: Double, y: Double) in CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height) }
        var path = Path()
        path.addLines([point(0.2, 0.86), point(0.5, 0.34), point(0.8, 0.86)])
        path.closeSubpath()
        path.addLines([point(0.42, 0.86), point(0.5, 0.62), point(0.58, 0.86)])
        path.closeSubpath()
        return path
    }
}

/// The rain fly: a wide roof over the body, and its guy lines out to the stakes.
private struct Fly: Shape {
    func path(in rect: CGRect) -> Path {
        let point = { (x: Double, y: Double) in CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height) }
        var roof = Path()
        roof.addLines([point(0.1, 0.74), point(0.5, 0.16), point(0.9, 0.74)])
        var lines = Path()
        lines.move(to: point(0.1, 0.74))
        lines.addLine(to: point(0.02, 0.88))
        lines.move(to: point(0.9, 0.74))
        lines.addLine(to: point(0.98, 0.88))
        let width = rect.width
        var path = roof.strokedPath(StrokeStyle(lineWidth: width * 0.1, lineCap: .round, lineJoin: .round))
        path.addPath(lines.strokedPath(StrokeStyle(lineWidth: width * 0.035, lineCap: .round)))
        return path
    }
}
