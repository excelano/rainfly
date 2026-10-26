// CrownInput.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

/// The Digital Crown as an endless run of detents. The crown turns round a short
/// wrapping range, since watchOS prepares every detent of the range up front and a
/// huge one runs the app out of memory.
enum Crown {
    static let detents = 100

    /// Whole detents turned from `old` to `new`, the short way round the range.
    static func steps(from old: Double, to new: Double) -> Int {
        let raw = (Int(new.rounded()) - Int(old.rounded())) % detents
        if raw > detents / 2 { return raw - detents }
        if raw <= -detents / 2 { return raw + detents }
        return raw
    }
}

extension View {
    /// Makes this view take the Digital Crown, calling `onStep` with the detents turned.
    /// Focus is claimed once the sheet has finished presenting, and again on a tap.
    func crownInput(_ value: Binding<Double>, focus: FocusState<Bool>.Binding, onStep: @escaping (Int) -> Void) -> some View {
        contentShape(.rect)
            .focusable()
            .focused(focus)
            .digitalCrownRotation(value, from: 0, through: Double(Crown.detents - 1), by: 1,
                                  sensitivity: .medium, isContinuous: true, isHapticFeedbackEnabled: true)
            .onChange(of: value.wrappedValue) { old, new in
                let steps = Crown.steps(from: old, to: new)
                if steps != 0 { onStep(steps) }
            }
            .onTapGesture { focus.wrappedValue = true }
            .task {
                try? await Task.sleep(for: .milliseconds(300))
                focus.wrappedValue = true
            }
    }
}
