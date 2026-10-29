// AddCampView.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI
import WatchKit

/// A new camp found by name, taken from the watch's position or typed as coordinates, then named.
struct AddCampView: View {
    @Environment(ForecastModel.self) private var model
    let done: (CampLocation?) -> Void
    @State private var located: Point?
    @State private var isLocating = false
    @State private var problem: String?

    var body: some View {
        List {
            NavigationLink {
                SearchCampView(near: model.night == nil && model.camps.saved.isEmpty ? nil : start, done: done)
            } label: {
                Label("Search", systemImage: "magnifyingglass")
            }
            Button {
                Task { await locate() }
            } label: {
                if isLocating {
                    ProgressView()
                } else {
                    Label("Use current location", systemImage: "location")
                }
            }
            .disabled(isLocating)
            NavigationLink {
                CoordinateEntryView(start: start, done: done)
            } label: {
                Label("Enter coordinates", systemImage: "number")
            }
            if let problem {
                Text(problem)
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
        .navigationTitle("Add camp")
        .navigationDestination(item: $located) { point in
            NameCampView(point: point, done: done)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", systemImage: "xmark") { done(nil) }
            }
        }
    }

    /// Where typing starts: the watch's last fetched position, or else the newest camp,
    /// since usually only the trailing digits differ.
    private var start: Point {
        let here = model.night?.location.name == CampLocation.hereName ? model.night?.location : nil
        guard let near = here ?? model.camps.saved.last else { return Point(latitude: 0, longitude: 0) }
        return Point(latitude: near.latitude, longitude: near.longitude)
    }

    private func locate() async {
        isLocating = true
        defer { isLocating = false }
        do {
            let here = try await model.locateHere()
            problem = nil
            located = Point(latitude: here.latitude, longitude: here.longitude)
        } catch {
            problem = ForecastError.noLocation.localizedDescription
        }
    }
}

/// Coordinate entry for gloves and one hand: the arrows pick a field, the Digital Crown
/// changes it.
private struct CoordinateEntryView: View {
    typealias Field = CoordinateEntry.Field

    let done: (CampLocation?) -> Void
    @State private var entry: CoordinateEntry
    @State private var field = Field.latDegrees
    @State private var crown = 0.0
    @FocusState private var isFocused: Bool

    init(start: Point, done: @escaping (CampLocation?) -> Void) {
        self.done = done
        _entry = State(initialValue: CoordinateEntry(latitude: start.latitude, longitude: start.longitude))
    }

    var body: some View {
        VStack(spacing: 6) {
            VStack(spacing: 6) {
                row([.latHemisphere, .latDegrees, .latMinutes, .latHundredths, .latTens, .latOnes])
                row([.lonHemisphere, .lonDegrees, .lonMinutes, .lonHundredths, .lonTens, .lonOnes])
            }
            .crownInput($crown, focus: $isFocused) { entry.adjust(field, by: $0) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Coordinates")
            .accessibilityValue("\(entry.latitude.text), \(entry.longitude.text)")
            .accessibilityAdjustableAction { direction in
                entry.adjust(field, by: direction == .increment ? 1 : -1)
            }
            HStack {
                Button("Previous field", systemImage: "chevron.left") { move(by: -1) }
                Button("Next field", systemImage: "chevron.right") { move(by: 1) }
            }
            .labelStyle(.iconOnly)
            NavigationLink("Next") {
                NameCampView(point: Point(latitude: entry.latitude.value, longitude: entry.longitude.value), done: done)
            }
            .tint(.accentColor)
        }
        .navigationTitle("Coordinates")
    }

    private func row(_ fields: [Field]) -> some View {
        HStack(spacing: 0) {
            ForEach(fields, id: \.self) { item in
                segment(item)
                switch item {
                case .latHemisphere, .lonHemisphere: Text(" ")
                case .latDegrees, .lonDegrees: Text("° ")
                case .latMinutes, .lonMinutes: Text(".")
                default: EmptyView()
                }
            }
        }
        .font(.system(size: 22, weight: .semibold, design: .monospaced))
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    private func segment(_ item: Field) -> some View {
        Text(entry.text(item))
            .padding(.vertical, 2)
            .background(item == field ? Color.accentColor.opacity(0.45) : .clear, in: .rect(cornerRadius: 3))
            .onTapGesture {
                field = item
                isFocused = true
            }
    }

    private func move(by offset: Int) {
        let all = Field.allCases
        field = all[(field.rawValue + offset + all.count) % all.count]
        isFocused = true
        WKInterfaceDevice.current().play(.click)
    }
}

/// Names the camp, suggesting the place the map service knows it as, and finds its zone
/// unless a search already did.
private struct NameCampView: View {
    @Environment(ForecastModel.self) private var model
    let point: Point
    let done: (CampLocation?) -> Void
    @State private var name: String
    @State private var place: CampPlace?

    init(point: Point, place: CampPlace? = nil, done: @escaping (CampLocation?) -> Void) {
        self.point = point
        self.done = done
        _name = State(initialValue: place?.name ?? "")
        _place = State(initialValue: place)
    }

    var body: some View {
        List {
            TextField("Name", text: $name)
            Text(CampsView.position(latitude: point.latitude, longitude: point.longitude))
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
            Button("Save") {
                let zone = place?.timeZone ?? CampPlace.estimatedZone(longitude: point.longitude)
                done(model.addCamp(CampLocation(name: name, latitude: point.latitude, longitude: point.longitude, timeZoneID: zone.identifier)))
            }
            .disabled(place == nil)
        }
        .navigationTitle("Name camp")
        .task {
            guard place == nil else { return }
            let found = await CampPlace.lookUp(latitude: point.latitude, longitude: point.longitude)
            if name.isEmpty, let suggested = found.name { name = suggested }
            place = found
        }
    }
}

/// Campgrounds, parks, towns and addresses by name, favouring those near the last position.
private struct SearchCampView: View {
    let near: Point?
    let done: (CampLocation?) -> Void
    @State private var query = ""
    @State private var results: [FoundPlace] = []
    @State private var isSearching = false
    @State private var problem: String?

    var body: some View {
        List {
            TextField("Place or address", text: $query)
                .onSubmit { Task { await search() } }
            if isSearching {
                ProgressView()
            }
            ForEach(results, id: \.self) { found in
                NavigationLink {
                    NameCampView(point: found.point, place: found.place, done: done)
                } label: {
                    VStack(alignment: .leading) {
                        Text(found.place.name ?? "")
                        Text(found.detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if let problem {
                Text(problem)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Search")
    }

    private func search() async {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        isSearching = true
        defer { isSearching = false }
        do {
            results = try await CampPlace.search(text, near: near)
            problem = results.isEmpty ? "Nothing found. Try a town or park nearby." : nil
        } catch {
            results = []
            problem = "Search needs a connection."
        }
    }
}
