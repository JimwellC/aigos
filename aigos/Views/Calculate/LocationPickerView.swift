//
//  LocationPickerView.swift
//  aigos
//
//  Visual location picker so users can SEE and CONFIRM a place. Online it searches
//  with MKLocalSearch and lets you drop a pin anywhere ("via Apple Maps"); offline
//  it still works via the bundled gazetteer (dots on the map + the same search box,
//  "≈ estimated distance"). The core app never requires this — it's an enhancement.
//

import SwiftUI
import MapKit
import CoreLocation

struct LocationPickerView: View {
    let title: String
    let personalPlaces: [PersonalPlace]
    let onConfirm: (PickedPlace) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [PickerResult] = []
    @State private var camera: MapCameraPosition = .region(LocationPickerView.phRegion)
    @State private var pinName: String?
    @State private var pinCoord: CLLocationCoordinate2D?
    @State private var address = ""
    @State private var locator = LocationHelper()
    @FocusState private var searchFocused: Bool

    static let phRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 12.8797, longitude: 121.7740),
        span: MKCoordinateSpan(latitudeDelta: 11, longitudeDelta: 11))

    private var gazetteer: [GazetteerEntry] { GazetteerRouteResolver.entries }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                mapLayer

                VStack(spacing: Space.sm) {
                    searchBar
                    if searchFocused && !results.isEmpty { resultsList }
                    Spacer()
                    if pinCoord != nil { confirmBar }
                }
                .padding(Space.md)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.aigosAmberDeep, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.tint(.white)
                }
            }
        }
        .onChange(of: query) { _, _ in runSearch() }
        .onChange(of: locator.point) { _, p in if let p { drop(CLLocationCoordinate2D(latitude: p.lat, longitude: p.lon), name: "My location") } }
    }

    // MARK: - Map

    private var mapLayer: some View {
        MapReader { proxy in
            Map(position: $camera) {
                // Gazetteer places as tappable reference dots (work offline).
                ForEach(gazetteer) { g in
                    Annotation(g.title, coordinate: g.coordinate) {
                        Button {
                            drop(g.coordinate, name: g.title)
                        } label: {
                            Circle()
                                .fill(Color.aigosAmber)
                                .frame(width: 9, height: 9)
                                .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 1))
                        }
                    }
                    .annotationTitles(.hidden)
                }
                if let pinCoord {
                    Marker(pinName ?? "Selected", coordinate: pinCoord).tint(.red)
                }
                UserAnnotation()
            }
            .mapStyle(.standard(elevation: .flat))
            .ignoresSafeArea()
            .onTapGesture { screenPoint in
                if let coord = proxy.convert(screenPoint, from: .local) {
                    drop(coord, name: nil)
                }
            }
        }
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: Space.sm) {
            Image(systemName: "magnifyingglass").foregroundStyle(.white.opacity(0.7))
            TextField("", text: $query, prompt: Text("Search a place or drop a pin").foregroundColor(.white.opacity(0.6)))
                .foregroundStyle(.white)
                .tint(.white)
                .autocorrectionDisabled()
                .focused($searchFocused)
            Button {
                locator.request()
            } label: {
                Image(systemName: "location.fill").foregroundStyle(Color.aigosAmber)
            }
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.55), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1))
    }

    private var resultsList: some View {
        VStack(spacing: 0) {
            ForEach(results) { r in
                Button { drop(r.coordinate, name: r.name) } label: {
                    HStack(spacing: Space.sm) {
                        Image(systemName: r.source == .apple ? "mappin.circle.fill" : "map.circle.fill")
                            .foregroundStyle(.white.opacity(0.9))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(r.name).font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                            if !r.subtitle.isEmpty {
                                Text(r.subtitle).font(.system(size: 12, design: .rounded)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                            }
                        }
                        Spacer()
                        Text(r.source == .apple ? "Apple Maps" : "gazetteer")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(.horizontal, Space.md).padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if r.id != results.last?.id { Divider().overlay(.white.opacity(0.12)) }
            }
        }
        .background(Color.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.15), lineWidth: 1))
    }

    // MARK: - Confirm

    private var confirmBar: some View {
        VStack(spacing: Space.sm) {
            HStack(spacing: Space.sm) {
                Image(systemName: "mappin.circle.fill").font(.system(size: 26)).foregroundStyle(.red)
                VStack(alignment: .leading, spacing: 2) {
                    Text(pinName ?? "Selected location")
                        .font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(.white).lineLimit(1)
                    Text(address.isEmpty ? "Tap to adjust, or Confirm" : address)
                        .font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
                }
                Spacer()
            }
            .padding(Space.md)
            .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            PrimaryButton(title: "Confirm location") {
                guard let c = pinCoord else { return }
                Haptics.tap(.medium)
                onConfirm(PickedPlace(name: pinName ?? "Selected", address: address, lat: c.latitude, lon: c.longitude))
                dismiss()
            }
        }
    }

    // MARK: - Logic

    private func runSearch() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { results = []; return }

        // Gazetteer (offline, instant).
        let lower = q.lowercased()
        let gaz = gazetteer
            .filter { $0.title.lowercased().contains(lower) || $0.aliases.contains { $0.lowercased().contains(lower) } }
            .prefix(4)
            .map { PickerResult(name: $0.title, subtitle: $0.subtitle, coordinate: $0.coordinate, source: .gazetteer) }
        results = Array(gaz)

        // Apple Maps (online). Appends when it returns.
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = q
        req.region = Self.phRegion
        MKLocalSearch(request: req).start { response, _ in
            guard query.trimmingCharacters(in: .whitespaces) == q else { return }
            let apple = (response?.mapItems ?? []).prefix(6).map {
                PickerResult(name: $0.name ?? "Place",
                             subtitle: $0.placemark.locality ?? $0.placemark.administrativeArea ?? "",
                             coordinate: $0.placemark.coordinate, source: .apple)
            }
            results = apple + Array(gaz)
        }
    }

    private func drop(_ coord: CLLocationCoordinate2D, name: String?) {
        pinCoord = coord
        pinName = name
        address = ""
        results = []
        searchFocused = false
        withAnimation(.easeOut(duration: 0.3)) {
            camera = .region(MKCoordinateRegion(center: coord, span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)))
        }
        // Reverse geocode for a friendly name + address (online).
        CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: coord.latitude, longitude: coord.longitude)) { placemarks, _ in
            // The geocoder completion is @Sendable and may run off-main — hop to
            // the main actor before mutating @State (Swift 6 / iOS 26).
            let first = placemarks?.first
            Task { @MainActor in
                guard let p = first else {
                    if pinName == nil { pinName = "Dropped pin" }
                    return
                }
                address = [p.name, p.locality, p.administrativeArea].compactMap { $0 }.joined(separator: ", ")
                if pinName == nil { pinName = p.name ?? p.locality ?? "Dropped pin" }
            }
        }
    }
}

/// A search result from either Apple Maps or the bundled gazetteer.
struct PickerResult: Identifiable, Equatable {
    enum Source { case apple, gazetteer }
    let id = UUID()
    let name: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D
    let source: Source

    static func == (a: PickerResult, b: PickerResult) -> Bool { a.id == b.id }
}

/// Minimal one-shot location request. Prompts for permission only when called.
@Observable
final class LocationHelper: NSObject, CLLocationManagerDelegate {
    var point: GeoPoint?
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
    }

    func request() {
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let c = locations.last?.coordinate { point = GeoPoint(lat: c.latitude, lon: c.longitude) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}

extension GazetteerEntry {
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: point.lat, longitude: point.lon) }
}

extension GeoPoint {
    var clCoordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lon) }
}

/// A small non-interactive map preview: origin → destination with a connecting
/// line (dashed = gazetteer estimate, solid = precise Apple Maps route).
struct RoutePreview: View {
    let origin: GeoPoint
    let destination: GeoPoint
    var precise: Bool = false
    /// The actual road polyline from MKDirections (online). When present it's drawn
    /// solid; otherwise a straight dashed line between the two points (offline).
    var routeCoordinates: [CLLocationCoordinate2D]? = nil

    var body: some View {
        Map(initialPosition: .region(region), interactionModes: []) {
            Marker("From", systemImage: "location.fill", coordinate: origin.clCoordinate).tint(.green)
            Marker("To", systemImage: "mappin", coordinate: destination.clCoordinate).tint(.red)
            if let coords = routeCoordinates, coords.count >= 2 {
                MapPolyline(coordinates: coords)
                    .stroke(Color.aigosAmber,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            } else {
                MapPolyline(coordinates: [origin.clCoordinate, destination.clCoordinate])
                    .stroke(Color.aigosAmber,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: precise ? [] : [6, 6]))
            }
        }
        .mapStyle(.standard(elevation: .flat))
    }

    private var region: MKCoordinateRegion {
        let minLat = min(origin.lat, destination.lat), maxLat = max(origin.lat, destination.lat)
        let minLon = min(origin.lon, destination.lon), maxLon = max(origin.lon, destination.lon)
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(latitudeDelta: max((maxLat - minLat) * 1.6, 0.06),
                                    longitudeDelta: max((maxLon - minLon) * 1.6, 0.06))
        return MKCoordinateRegion(center: center, span: span)
    }
}

extension MKPolyline {
    /// The polyline's points as an array of coordinates (for drawing the route
    /// with SwiftUI's `MapPolyline`).
    var coordinates: [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid,
                                              count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}
