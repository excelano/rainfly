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
                if model.settings.bagRatingC != nil {
                    QuantityRow(quantity: .bagRating(units), value: bagRating)
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

    /// The rating as a plain value. A binding unwrapped from the optional crashes when the
    /// switch turns off, because SwiftUI reads the row once more as it removes it.
    private var bagRating: Binding<Double> {
        Binding {
            model.settings.bagRatingC ?? Self.defaultBagRatingC
        } set: { rating in
            model.settings.bagRatingC = rating
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
