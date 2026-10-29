// SettingsScreen.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI
import WatchConnectivity

struct SettingsScreen: View {
    @Environment(ForecastModel.self) private var model
    @Environment(\.diaryRecorder) private var recorder

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
                if model.settings.bagRatingC != nil {
                    QuantityStepper(quantity: .bagRating(units), value: bagRating)
                }
            } footer: {
                Text("Your sleeping bag's comfort rating, to warn when the night will be colder.")
            }
            Section {
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
            } header: {
                Text("Units")
            }
            Section {
                NavigationLink("Checks") {
                    ChecksSettingsScreen()
                }
            } footer: {
                Text("When each check puts the fly on.")
            }
            Section {
                Toggle("Dew diary", isOn: $model.preferences.dewDiary)
                if model.preferences.dewDiary, let recorder {
                    ShareToggle(recorder: recorder)
                }
                if let recorder, model.preferences.dewDiary || !recorder.diary.nights.isEmpty {
                    NavigationLink("Nights and suggestions") {
                        DiaryScreen(recorder: recorder)
                    }
                }
            } footer: {
                Text("Each morning, note what you found on something left under the sky, and see how the dew forecast did at your campsites.")
            }
            Section {
                Toggle("Pressure alert", isOn: $model.preferences.pressureWatch)
                    .onChange(of: model.preferences.pressureWatch) {
                        if model.preferences.pressureWatch { Task { await PressureWatch.requestPermission() } }
                    }
            } footer: {
                Text("Warns overnight when the pressure falls fast and the fly is off. iOS gives the phone only occasional time in the background, so this is a rough check. While your watch has its own pressure alert on, the phone stays quiet and the watch warns. \(PressureWatch.status)")
            }
            if WCSession.isSupported(), WCSession.default.isWatchAppInstalled {
                Section {
                } footer: {
                    Text("Camps, the trip, checks and units are shared with Rainfly on your Apple Watch.")
                }
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

struct ChecksSettingsScreen: View {
    @Environment(ForecastModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let units = model.preferences.units
        Form {
            Section {
                QuantityStepper(quantity: .rainChance, value: $model.settings.rainChance)
            } header: {
                Text("Rain")
            } footer: {
                Text("Rainfly on when any hour of the night reaches this chance of rain, or rain is forecast to fall.")
            }
            Section {
                QuantityStepper(quantity: .morningRainChance, value: $model.settings.morningRainChance)
            } header: {
                Text("Morning rain")
            } footer: {
                Text("The same, for the hours between sunrise and breaking camp.")
            }
            Section {
                QuantityStepper(quantity: .windRain(units), value: $model.settings.windRainMS)
            } header: {
                Text("Wind-driven rain")
            } footer: {
                Text("Rainfly on when the wind or its gusts pass this in an hour with any chance of rain.")
            }
            Section {
                QuantityStepper(quantity: .dewSpread(units), value: $model.settings.dewSpreadC)
                QuantityStepper(quantity: .clearSky, value: $model.settings.clearSky)
                QuantityStepper(quantity: .calmWind(units), value: $model.settings.calmWindMS)
            } header: {
                Text("Dew and frost")
            } footer: {
                Text("Rainfly on when the air comes this close to its dew point under a clear sky and calm air, all three in the same hour. Below freezing it is frost.")
            }
            Section {
                QuantityStepper(quantity: .cold(units), value: $model.settings.coldC)
            } header: {
                Text("Cold")
            } footer: {
                Text("Rainfly on when the night drops below this, since the fly keeps the tent warmer.")
            }
            Section {
                QuantityStepper(quantity: .ventHumidity, value: $model.settings.ventHumidity)
            } header: {
                Text("Vents")
            } footer: {
                Text("With the fly on, suggests opening the vents when the humidity reaches this or the air is calm.")
            }
            Section {
                Button("Reset to defaults") {
                    model.settings = model.settings.resettingThresholds()
                }
                .disabled(model.settings == model.settings.resettingThresholds())
            } footer: {
                Text("Storms always put the fly on and have no setting.")
            }
        }
        .navigationTitle("Checks")
    }
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
