// SettingsScreen.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

struct SettingsScreen: View {
    @Environment(ForecastModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let units = model.preferences.units
        Form {
            Section {
                DatePicker("Break camp", selection: packBy, displayedComponents: .hourAndMinute)
            } header: {
                Text("Morning")
            } footer: {
                Text("When you plan to take the tent down. Morning rain is checked until then, and tonight's forecast shows after it.")
            }
            Section {
                Toggle("Bag rating", isOn: hasBagRating)
                if let rating = Binding($model.settings.bagRatingC) {
                    QuantityStepper(quantity: .bagRating(units), value: rating)
                }
            } footer: {
                Text("Your sleeping bag's comfort rating, to warn when the night will be colder.")
            }
            Section("Units") {
                Picker("Temperature", selection: $model.preferences.units.fahrenheit) {
                    Text("°C").tag(false)
                    Text("°F").tag(true)
                }
                .pickerStyle(.segmented)
                Picker("Wind", selection: $model.preferences.units.mph) {
                    Text("m/s").tag(false)
                    Text("mph").tag(true)
                }
                .pickerStyle(.segmented)
            }
            Section {
                QuantityStepper(quantity: .rainChance, value: $model.settings.rainChance)
                QuantityStepper(quantity: .morningRainChance, value: $model.settings.morningRainChance)
                QuantityStepper(quantity: .windRain(units), value: $model.settings.windRainMS)
                QuantityStepper(quantity: .dewSpread(units), value: $model.settings.dewSpreadC)
                QuantityStepper(quantity: .clearSky, value: $model.settings.clearSky)
                QuantityStepper(quantity: .calmWind(units), value: $model.settings.calmWindMS)
                QuantityStepper(quantity: .cold(units), value: $model.settings.coldC)
                QuantityStepper(quantity: .ventHumidity, value: $model.settings.ventHumidity)
                Button("Reset to defaults") {
                    model.settings = model.settings.resettingThresholds()
                }
                .disabled(model.settings == model.settings.resettingThresholds())
            } header: {
                Text("Triggers")
            } footer: {
                Text("Any one check that fires puts the fly on. Dew needs the spread, a clear sky and calm air together.")
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

/// One setting, stepped in its shown unit and stored in °C, m/s or a fraction.
private struct QuantityStepper: View {
    let quantity: Quantity
    @Binding var value: Double

    var body: some View {
        Stepper(value: shown, in: quantity.range, step: quantity.step) {
            LabeledContent(quantity.title, value: quantity.text(value))
                .monospacedDigit()
        }
    }

    private var shown: Binding<Double> {
        Binding {
            quantity.display(value)
        } set: { shown in
            if shown != quantity.display(value) { value = quantity.stored(shown) }
        }
    }
}
