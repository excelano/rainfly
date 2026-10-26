// SettingsView.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

struct SettingsView: View {
    @Environment(ForecastModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let units = model.preferences.units
        List {
            Section {
                NavigationLink {
                    DatePicker("Break camp", selection: packBy, displayedComponents: .hourAndMinute)
                        .navigationTitle("Break camp")
                } label: {
                    LabeledContent("Break camp", value: packBy.wrappedValue.formatted(date: .omitted, time: .shortened))
                }
            } header: {
                Text("Morning")
            } footer: {
                Text("When you plan to take the tent down. Morning rain is checked until then, and tonight's forecast shows after it.")
            }
            Section {
                Toggle("Bag rating", isOn: hasBagRating)
                if let rating = Binding($model.settings.bagRatingC) {
                    QuantityRow(quantity: .bagRating(units), value: rating)
                }
            } footer: {
                Text("Your sleeping bag's comfort rating, to warn when the night will be colder.")
            }
            Section("Units") {
                Picker("Temperature", selection: $model.preferences.units.fahrenheit) {
                    Text("°C").tag(false)
                    Text("°F").tag(true)
                }
                Picker("Wind", selection: $model.preferences.units.mph) {
                    Text("m/s").tag(false)
                    Text("mph").tag(true)
                }
            }
            Section("Triggers") {
                QuantityRow(quantity: .rainChance, value: $model.settings.rainChance)
                QuantityRow(quantity: .morningRainChance, value: $model.settings.morningRainChance)
                QuantityRow(quantity: .windRain(units), value: $model.settings.windRainMS)
                QuantityRow(quantity: .dewSpread(units), value: $model.settings.dewSpreadC)
                QuantityRow(quantity: .clearSky, value: $model.settings.clearSky)
                QuantityRow(quantity: .calmWind(units), value: $model.settings.calmWindMS)
                QuantityRow(quantity: .cold(units), value: $model.settings.coldC)
                QuantityRow(quantity: .ventHumidity, value: $model.settings.ventHumidity)
                Button("Reset to defaults") {
                    model.settings = model.settings.resettingThresholds()
                }
                .disabled(model.settings == model.settings.resettingThresholds())
            }
            Section {
                Toggle("Pressure watch", isOn: $model.preferences.pressureWatch)
                    .onChange(of: model.preferences.pressureWatch) {
                        if model.preferences.pressureWatch { Task { await PressureWatch.requestPermission() } }
                    }
            } footer: {
                Text("Warns overnight when the pressure falls fast and the fly is off.")
            }
        }
        .navigationTitle("Settings")
    }

    /// Break-camp time (pack-by) as a time today, which the picker needs; only the hour and minute are kept.
    private var packBy: Binding<Date> {
        Binding {
            let minutes = model.settings.packByMinutes
            return Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            model.settings.packByMinutes = (parts.hour ?? 8) * 60 + (parts.minute ?? 0)
        }
    }

    private var hasBagRating: Binding<Bool> {
        Binding {
            model.settings.bagRatingC != nil
        } set: { on in
            model.settings.bagRatingC = on ? Self.defaultBagRatingC : nil
        }
    }

    private static let defaultBagRatingC = 5.0
}

/// A setting stored in °C, m/s or a fraction and shown in the chosen unit, with the range
/// and step the editor moves in.
struct Quantity: Sendable {
    let title: String
    let range: ClosedRange<Double>
    let step: Double
    let shown: @Sendable (Double) -> Double
    let stored: @Sendable (Double) -> Double
    let suffix: String

    /// The stored value as shown, on the nearest step inside the range.
    func display(_ value: Double) -> Double {
        let snapped = (shown(value) / step).rounded() * step
        return min(max(snapped, range.lowerBound), range.upperBound)
    }

    func text(_ value: Double) -> String {
        format(display(value))
    }

    func format(_ shown: Double) -> String {
        shown.formatted(.number.precision(.fractionLength(step < 1 ? 1 : 0))) + suffix
    }

    private static func percent(_ title: String, _ range: ClosedRange<Double>) -> Quantity {
        Quantity(title: title, range: range, step: 5, shown: { $0 * 100 }, stored: { $0 / 100 }, suffix: "%")
    }

    private static func temperature(_ title: String, _ units: DisplayUnits, c: ClosedRange<Double>, f: ClosedRange<Double>) -> Quantity {
        Quantity(
            title: title, range: units.fahrenheit ? f : c, step: 1,
            shown: units.temperature, stored: units.celsius, suffix: "°"
        )
    }

    private static func speed(_ title: String, _ units: DisplayUnits, ms: ClosedRange<Double>, mph: ClosedRange<Double>) -> Quantity {
        Quantity(
            title: title, range: units.mph ? mph : ms, step: units.mph ? 1 : 0.5,
            shown: units.speed, stored: units.metersPerSecond, suffix: " " + units.speedUnit
        )
    }

    static let rainChance = percent("Rain chance", 5...100)
    static let morningRainChance = percent("Morning rain chance", 5...100)
    static let clearSky = percent("Clear sky below", 5...80)
    static let ventHumidity = percent("Vent humidity", 50...100)

    static func windRain(_ units: DisplayUnits) -> Quantity {
        speed("Wind-driven rain over", units, ms: 3...20, mph: 5...45)
    }

    static func calmWind(_ units: DisplayUnits) -> Quantity {
        speed("Calm below", units, ms: 0.5...8, mph: 1...18)
    }

    static func dewSpread(_ units: DisplayUnits) -> Quantity {
        Quantity(
            title: "Dew spread", range: units.fahrenheit ? 1...11 : 0.5...6, step: units.fahrenheit ? 1 : 0.5,
            shown: units.temperatureSpan, stored: units.celsiusSpan, suffix: "°"
        )
    }

    static func cold(_ units: DisplayUnits) -> Quantity {
        temperature("Cold below", units, c: -10...20, f: 15...68)
    }

    static func bagRating(_ units: DisplayUnits) -> Quantity {
        temperature("Comfort rating", units, c: -30...20, f: -20...68)
    }
}

private struct QuantityRow: View {
    let quantity: Quantity
    @Binding var value: Double

    var body: some View {
        NavigationLink {
            QuantityEditor(quantity: quantity, value: $value)
        } label: {
            LabeledContent(quantity.title, value: quantity.text(value))
        }
    }
}

/// One value, turned with the Digital Crown or stepped with the buttons.
private struct QuantityEditor: View {
    let quantity: Quantity
    @Binding var value: Double
    @State private var shown = 0.0
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 8) {
            Text(quantity.format(shown))
                .font(.system(size: 36, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .focusable()
                .focused($focused)
                .digitalCrownRotation(
                    $shown, from: quantity.range.lowerBound, through: quantity.range.upperBound, by: quantity.step,
                    sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true
                )
                .accessibilityLabel(quantity.title)
                .accessibilityValue(quantity.format(shown))
                .accessibilityAdjustableAction { direction in
                    move(direction == .increment ? 1 : -1)
                }
            HStack {
                Button("Less", systemImage: "minus") { move(-1) }
                Button("More", systemImage: "plus") { move(1) }
            }
            .labelStyle(.iconOnly)
        }
        .navigationTitle(quantity.title)
        .onAppear {
            shown = quantity.display(value)
            focused = true
        }
        .onChange(of: shown) {
            if shown != quantity.display(value) { value = quantity.stored(shown) }
        }
    }

    private func move(_ steps: Double) {
        shown = min(max(shown + steps * quantity.step, quantity.range.lowerBound), quantity.range.upperBound)
    }
}
