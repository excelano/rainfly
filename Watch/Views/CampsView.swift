// CampsView.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

/// The saved camps and the trip. Tapping a camp shows it tonight; the trip picks each
/// night's camp ahead of time.
struct CampsView: View {
    @Environment(ForecastModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var isAdding = false

    var body: some View {
        List {
            Section("Tonight") {
                CampRow(name: CampLocation.hereName, detail: "Your position", isShown: model.campName == CampLocation.hereName) {
                    show(CampLocation.hereName)
                }
                ForEach(model.camps.saved, id: \.name) { camp in
                    CampRow(name: camp.name, detail: Self.position(latitude: camp.latitude, longitude: camp.longitude), isShown: model.campName == camp.name) {
                        show(camp.name)
                    }
                }
                .onDelete { offsets in
                    let names = offsets.map { model.camps.saved[$0].name }
                    Task { for name in names { await model.removeCamp(named: name) } }
                }
                Button("Add camp", systemImage: "plus") { isAdding = true }
            }
            TripSection()
        }
        .navigationTitle("Camps")
        .sheet(isPresented: $isAdding) {
            NavigationStack {
                AddCampView { isAdding = false }
            }
        }
    }

    private func show(_ name: String) {
        Task { await model.show(name) }
        dismiss()
    }

    static func position(latitude: Double, longitude: Double) -> String {
        DDM(latitude, isLatitude: true).text + "\n" + DDM(longitude, isLatitude: false).text
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
                VStack(alignment: .leading) {
                    Text(name)
                    Text(detail)
                        .font(.caption2.monospacedDigit())
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
    }
}

private struct TripSection: View {
    @Environment(ForecastModel.self) private var model

    var body: some View {
        Section {
            ForEach(model.camps.trip, id: \.self) { night in
                TripRow(night: night, isReady: model.cachedNight(night) != nil, isTonight: night.date == model.nightDate())
            }
            .onDelete { offsets in
                let dates = offsets.map { model.camps.trip[$0].date }
                Task { for date in dates { await model.removeNight(on: date) } }
            }
            NavigationLink {
                TripNightEditor()
            } label: {
                Label("Add night", systemImage: "calendar.badge.plus")
            }
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
    let night: TripNight
    let isReady: Bool
    let isTonight: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(isTonight ? "Tonight" : night.date.start(in: .current).formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(night.campName)
            }
            Spacer()
            Image(systemName: isReady ? "checkmark.circle.fill" : "arrow.down.circle")
                .foregroundStyle(isReady ? Color.accentColor : .secondary)
                .accessibilityLabel(isReady ? "Downloaded" : "Not downloaded")
        }
    }
}

/// A night of the trip: which camp, and the date of its evening.
private struct TripNightEditor: View {
    @Environment(ForecastModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var campName = ""
    @State private var date = Date.now

    var body: some View {
        List {
            Picker("Camp", selection: $campName) {
                ForEach(model.camps.saved, id: \.name) { camp in
                    Text(camp.name).tag(camp.name)
                }
            }
            DatePicker("Night of", selection: $date, in: model.nightDate().start(in: .current)..., displayedComponents: .date)
            Button("Add") {
                let night = NightDate(date, calendar: .current)
                Task { await model.plan(campName, on: night) }
                dismiss()
            }
        }
        .navigationTitle("Add night")
        .onAppear {
            let last = model.camps.trip.last
            campName = last?.campName ?? model.camps.saved.first?.name ?? ""
            let next = last.map { max($0.date.adding(days: 1), model.nightDate()) } ?? model.nightDate()
            date = next.start(in: .current)
        }
    }
}
