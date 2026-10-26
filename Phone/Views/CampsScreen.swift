// CampsScreen.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

/// The saved camps and the trip. Tapping a camp shows it tonight; the trip picks each
/// night's camp ahead of time.
struct CampsScreen: View {
    @Environment(ForecastModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var isAddingCamp = false
    @State private var isAddingNight = false

    var body: some View {
        List {
            Section("Tonight") {
                CampRow(name: CampLocation.hereName, detail: "Your position", isShown: model.campName == CampLocation.hereName) {
                    show(CampLocation.hereName)
                }
                ForEach(model.camps.saved, id: \.name) { camp in
                    CampRow(name: camp.name, detail: Self.position(of: camp), isShown: model.campName == camp.name) {
                        show(camp.name)
                    }
                }
                .onDelete { offsets in
                    let names = offsets.map { model.camps.saved[$0].name }
                    Task { for name in names { await model.removeCamp(named: name) } }
                }
                Button("Add camp", systemImage: "plus") { isAddingCamp = true }
            }
            TripSection(isAddingNight: $isAddingNight)
        }
        .navigationTitle("Camps")
        .sheet(isPresented: $isAddingCamp) {
            NavigationStack {
                AddCampScreen { isAddingCamp = false }
            }
        }
        .sheet(isPresented: $isAddingNight) {
            NavigationStack {
                TripNightEditor()
            }
            .presentationDetents([.medium])
        }
    }

    private func show(_ name: String) {
        Task { await model.show(name) }
        dismiss()
    }

    static func position(of camp: CampLocation) -> String {
        position(Point(latitude: camp.latitude, longitude: camp.longitude))
    }

    static func position(_ point: Point) -> String {
        DDM(point.latitude, isLatitude: true).text + "  " + DDM(point.longitude, isLatitude: false).text
    }
}

private struct CampRow: View {
    let name: String
    let detail: String
    let isShown: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                    Text(detail)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isShown {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                        .accessibilityLabel("Shown tonight")
                }
            }
        }
        .tint(.primary)
    }
}

private struct TripSection: View {
    @Environment(ForecastModel.self) private var model
    @Binding var isAddingNight: Bool

    var body: some View {
        Section {
            ForEach(model.camps.trip, id: \.self) { night in
                if let cached = model.cachedNight(night) {
                    NavigationLink {
                        TripNightScreen(night: night, forecast: cached)
                    } label: {
                        TripRow(night: night, forecast: cached)
                    }
                } else {
                    TripRow(night: night, forecast: nil)
                }
            }
            .onDelete { offsets in
                let dates = offsets.map { model.camps.trip[$0].date }
                Task { for date in dates { await model.removeNight(on: date) } }
            }
            Button("Add night", systemImage: "calendar.badge.plus") { isAddingNight = true }
                .disabled(model.camps.saved.isEmpty)
            if !model.camps.trip.isEmpty {
                Button {
                    Task { await model.downloadTrip() }
                } label: {
                    if model.isDownloading {
                        ProgressView()
                    } else {
                        Label("Download trip", systemImage: "arrow.down.circle")
                    }
                }
                .disabled(model.isDownloading)
            }
            if let report = model.downloadReport {
                Text(report)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Trip")
        } footer: {
            Text(model.camps.saved.isEmpty
                 ? "Add a camp to plan the nights of a trip."
                 : "Each evening shows that night's camp. Download before you lose signal.")
        }
    }
}

private struct TripRow: View {
    @Environment(ForecastModel.self) private var model
    let night: TripNight
    let forecast: NightForecast?

    var body: some View {
        HStack(spacing: 12) {
            if let text {
                TentGlyph(flyOn: text.verdict.flyOn)
                    .frame(width: 32, height: 32)
                    .foregroundStyle(text.verdict.flyOn ? Color.accentColor : .secondary)
            } else {
                Image(systemName: "arrow.down.circle")
                    .font(.title2)
                    .frame(width: 32, height: 32)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(TripNightScreen.title(night, tonight: model.nightDate()))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(night.campName)
                Text(text.map { "\($0.headline) · \($0.reason)" } ?? "Not downloaded")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var text: VerdictText? {
        forecast.map {
            VerdictText(night: $0, verdict: FlyEngine.evaluate($0, settings: model.settings), settings: model.settings, units: model.preferences.units)
        }
    }
}

/// A downloaded night of the trip, laid out as the main screen is.
private struct TripNightScreen: View {
    @Environment(ForecastModel.self) private var model
    let night: TripNight
    let forecast: NightForecast

    var body: some View {
        TimelineView(.everyMinute) { context in
            NightView(
                text: VerdictText(
                    night: forecast, verdict: FlyEngine.evaluate(forecast, settings: model.settings),
                    settings: model.settings, units: model.preferences.units
                ),
                now: context.date,
                attribution: model.attribution,
                period: night.date == model.nightDate() ? nil : Self.title(night, tonight: model.nightDate())
            )
        }
        .navigationTitle(night.campName)
        .navigationBarTitleDisplayMode(.inline)
    }

    static func title(_ night: TripNight, tonight: NightDate) -> String {
        night.date == tonight
            ? "Tonight"
            : night.date.start(in: .current).formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}

/// A night of the trip: which camp, and the date of its evening.
private struct TripNightEditor: View {
    @Environment(ForecastModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var campName = ""
    @State private var date = Date.now

    var body: some View {
        Form {
            Picker("Camp", selection: $campName) {
                ForEach(model.camps.saved, id: \.name) { camp in
                    Text(camp.name).tag(camp.name)
                }
            }
            DatePicker("Night of", selection: $date, in: model.nightDate().start(in: .current)..., displayedComponents: .date)
        }
        .navigationTitle("Add night")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    let night = NightDate(date, calendar: .current)
                    Task { await model.plan(campName, on: night) }
                    dismiss()
                }
            }
        }
        .onAppear {
            let last = model.camps.trip.last
            campName = last?.campName ?? model.camps.saved.first?.name ?? ""
            let next = last.map { max($0.date.adding(days: 1), model.nightDate()) } ?? model.nightDate()
            date = next.start(in: .current)
        }
    }
}
