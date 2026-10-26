// AddCampScreen.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import MapKit
import SwiftUI

/// A new camp found by name, taken from the phone's position, placed on a map or typed as
/// coordinates, then named.
struct AddCampScreen: View {
    @Environment(ForecastModel.self) private var model
    let done: () -> Void
    @State private var located: Point?
    @State private var isLocating = false
    @State private var problem: String?

    var body: some View {
        List {
            NavigationLink {
                SearchCampScreen(near: near, done: done)
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
                MapPickScreen(start: near, done: done)
            } label: {
                Label("Pick on map", systemImage: "map")
            }
            NavigationLink {
                CoordinateFieldsScreen(done: done)
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
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $located) { point in
            NameCampScreen(point: point, done: done)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: done)
            }
        }
    }

    /// The phone's last fetched position, or else the newest camp.
    private var near: Point? {
        let here = model.night?.location.name == CampLocation.hereName ? model.night?.location : nil
        return (here ?? model.camps.saved.last).map { Point(latitude: $0.latitude, longitude: $0.longitude) }
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

/// Campgrounds, parks, towns and addresses by name, favouring those near the last position.
private struct SearchCampScreen: View {
    let near: Point?
    let done: () -> Void
    @State private var query = ""
    @State private var results: [FoundPlace] = []
    @State private var isSearching = false
    @State private var problem: String?

    var body: some View {
        List {
            if isSearching {
                ProgressView()
            }
            ForEach(results, id: \.self) { found in
                NavigationLink {
                    NameCampScreen(point: found.point, place: found.place, done: done)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(found.place.name ?? "")
                        Text(found.detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if let problem {
                Text(problem)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Campground, park, town or address")
        .onSubmit(of: .search) { Task { await search() } }
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

/// A map to pan under a fixed pin. It only places the camp; it shows no weather.
private struct MapPickScreen: View {
    let done: () -> Void
    @State private var position: MapCameraPosition
    @State private var center: CLLocationCoordinate2D?

    init(start: Point?, done: @escaping () -> Void) {
        self.done = done
        let initial: MapCameraPosition = start.map {
            .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude),
                latitudinalMeters: 20_000, longitudinalMeters: 20_000
            ))
        } ?? .userLocation(fallback: .automatic)
        _position = State(initialValue: initial)
    }

    var body: some View {
        Map(position: $position) {
            UserAnnotation()
        }
        .mapStyle(.hybrid(elevation: .realistic))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .onMapCameraChange(frequency: .continuous) { context in
            center = context.region.center
        }
        .overlay {
            Image(systemName: "mappin")
                .font(.largeTitle)
                .foregroundStyle(.red)
                .offset(y: -16)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if let center {
                    Text(CampsScreen.position(Point(latitude: center.latitude, longitude: center.longitude)))
                        .font(.footnote.monospacedDigit())
                }
                NavigationLink("Camp here") {
                    if let center {
                        NameCampScreen(point: Point(latitude: center.latitude, longitude: center.longitude), done: done)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(center == nil)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(.regularMaterial)
        }
        .navigationTitle("Pick on map")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Latitude and longitude typed in, as decimal degrees or degrees and decimal minutes.
private struct CoordinateFieldsScreen: View {
    let done: () -> Void
    @State private var latitude = ""
    @State private var longitude = ""

    private var point: Point? {
        guard let lat = CoordinateText.parse(latitude, isLatitude: true),
              let lon = CoordinateText.parse(longitude, isLatitude: false)
        else { return nil }
        return Point(latitude: lat, longitude: lon)
    }

    var body: some View {
        Form {
            Section("Latitude") {
                TextField("Latitude", text: $latitude, prompt: Text("N 39° 56.334 or 39.9389"))
            }
            Section {
                TextField("Longitude", text: $longitude, prompt: Text("W 105° 36.636 or -105.6106"))
            } header: {
                Text("Longitude")
            } footer: {
                if let point {
                    Text(CampsScreen.position(point))
                        .monospacedDigit()
                } else if !latitude.isEmpty && !longitude.isEmpty {
                    Text("Use N or S and E or W, or a minus for south and west.")
                }
            }
        }
        .font(.body.monospacedDigit())
        .autocorrectionDisabled()
        .textInputAutocapitalization(.characters)
        .navigationTitle("Coordinates")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                NavigationLink("Next") {
                    if let point {
                        NameCampScreen(point: point, done: done)
                    }
                }
                .disabled(point == nil)
            }
        }
    }
}

/// Names the camp, suggesting the place the map service knows it as, and finds its zone
/// unless a search already did.
private struct NameCampScreen: View {
    @Environment(ForecastModel.self) private var model
    let point: Point
    let done: () -> Void
    @State private var name: String
    @State private var place: CampPlace?

    init(point: Point, place: CampPlace? = nil, done: @escaping () -> Void) {
        self.point = point
        self.done = done
        _name = State(initialValue: place?.name ?? "")
        _place = State(initialValue: place)
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
            } footer: {
                Text(CampsScreen.position(point))
                    .monospacedDigit()
            }
        }
        .navigationTitle("Name camp")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if place == nil {
                    ProgressView()
                } else {
                    Button("Save") {
                        let zone = place?.timeZone ?? CampPlace.estimatedZone(longitude: point.longitude)
                        model.addCamp(CampLocation(name: name, latitude: point.latitude, longitude: point.longitude, timeZoneID: zone.identifier))
                        done()
                    }
                }
            }
        }
        .task {
            guard place == nil else { return }
            let found = await CampPlace.lookUp(latitude: point.latitude, longitude: point.longitude)
            if name.isEmpty, let suggested = found.name { name = suggested }
            place = found
        }
    }
}
