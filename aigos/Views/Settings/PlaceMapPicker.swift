//
//  PlaceMapPicker.swift
//  aigos
//
//  Center-pin location picker for personal places ("Home", "Office"). A fixed
//  amber pin sits in the middle of the map and the map moves *under* it — the
//  centre coordinate is what gets saved. Search (MKLocalSearch + gazetteer),
//  drop-by-panning, and "use my location" all recentre the map. Reuses the same
//  offline-friendly search + one-shot location permission as `LocationPickerView`
//  (NSLocationWhenInUseUsageDescription is already declared).
//

import SwiftUI
import MapKit
import CoreLocation

struct PlaceMapPicker: View {
    let placeName: String
    let initial: CLLocationCoordinate2D?
    let onConfirm: (PickedPlace) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var camera: MapCameraPosition
    @State private var centerCoord: CLLocationCoordinate2D
    @State private var address = ""
    @State private var query = ""
    @State private var results: [PickerResult] = []
    @State private var locator = LocationHelper()
    @FocusState private var searchFocused: Bool

    private var gazetteer: [GazetteerEntry] { GazetteerRouteResolver.entries }

    init(placeName: String, initial: CLLocationCoordinate2D?, onConfirm: @escaping (PickedPlace) -> Void) {
        self.placeName = placeName
        self.initial = initial
        self.onConfirm = onConfirm
        let start = initial ?? LocationPickerView.phRegion.center
        let span = initial != nil
            ? MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
            : LocationPickerView.phRegion.span
        _camera = State(initialValue: .region(MKCoordinateRegion(center: start, span: span)))
        _centerCoord = State(initialValue: start)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                mapLayer
                centerPin

                VStack(spacing: Space.sm) {
                    searchBar
                    if let msg = locator.errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "location.slash.fill")
                            Text(msg).font(.system(size: 12, weight: .medium, design: .rounded))
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, Space.md).padding(.vertical, 8)
                        .background(Color.aigosAmberDeep.opacity(0.9), in: Capsule())
                    }
                    if searchFocused && !results.isEmpty { resultsList }
                    Spacer()
                    confirmBar
                }
                .padding(Space.md)
            }
            .navigationTitle(placeName.isEmpty ? "Set location" : placeName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.aigosAmberDeep, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.tint(.white)
                }
            }
        }
        .onAppear { reverseGeocode(centerCoord) }
        .onChange(of: query) { _, _ in runSearch() }
        .onChange(of: locator.point) { _, p in
            if let p { recenter(CLLocationCoordinate2D(latitude: p.lat, longitude: p.lon)) }
        }
    }

    // MARK: - Map + fixed centre pin

    private var mapLayer: some View {
        Map(position: $camera) {
            // Gazetteer reference dots (work offline).
            ForEach(gazetteer) { g in
                Annotation(g.title, coordinate: g.coordinate) {
                    Circle()
                        .fill(Color.aigosAmber.opacity(0.55))
                        .frame(width: 7, height: 7)
                        .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 1))
                }
                .annotationTitles(.hidden)
            }
            UserAnnotation()
        }
        .mapStyle(.standard(elevation: .flat))
        .ignoresSafeArea()
        .onMapCameraChange(frequency: .onEnd) { ctx in
            centerCoord = ctx.region.center
            reverseGeocode(ctx.region.center)
        }
    }

    /// A large amber pin locked to the centre of the screen (tip at the centre).
    private var centerPin: some View {
        VStack(spacing: 0) {
            Image(systemName: "mappin")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(Color.aigosAmber)
                .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 3)
            Circle()
                .fill(Color.black.opacity(0.25))
                .frame(width: 8, height: 4)
                .blur(radius: 1)
        }
        .offset(y: -26)                 // lift so the needle tip sits on the centre dot
        .allowsHitTesting(false)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: Space.sm) {
            Image(systemName: "magnifyingglass").foregroundStyle(.white.opacity(0.7))
            TextField("", text: $query,
                      prompt: Text("Search for your location").foregroundColor(.white.opacity(0.6)))
                .foregroundStyle(.white)
                .tint(.white)
                .autocorrectionDisabled()
                .focused($searchFocused)
            Button { locator.request() } label: {
                if locator.isLocating {
                    ProgressView().tint(Color.aigosAmber).frame(width: 20, height: 20)
                } else {
                    Image(systemName: "location.fill").foregroundStyle(Color.aigosAmber)
                }
            }
            .disabled(locator.isLocating)
            .accessibilityLabel("Use my location")
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.55), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1))
    }

    private var resultsList: some View {
        VStack(spacing: 0) {
            ForEach(results) { r in
                Button { recenter(r.coordinate); searchFocused = false; query = "" } label: {
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
                Image(systemName: "mappin.circle.fill").font(.system(size: 26)).foregroundStyle(Color.aigosAmber)
                Text(address.isEmpty ? "Move the map to place the pin" : address)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Space.md)
            .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            PrimaryButton(title: placeName.isEmpty ? "Set location" : "Set as \(placeName)") {
                Haptics.tap(.medium)
                let short = address.split(separator: ",").first.map(String.init) ?? (placeName.isEmpty ? "Pinned location" : placeName)
                onConfirm(PickedPlace(name: short, address: address,
                                      lat: centerCoord.latitude, lon: centerCoord.longitude))
                dismiss()
            }
        }
    }

    // MARK: - Logic

    private func recenter(_ coord: CLLocationCoordinate2D) {
        results = []
        withAnimation(.easeOut(duration: 0.35)) {
            camera = .region(MKCoordinateRegion(center: coord,
                                                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)))
        }
        centerCoord = coord
        reverseGeocode(coord)
    }

    private func runSearch() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { results = []; return }

        let lower = q.lowercased()
        let gaz = gazetteer
            .filter { $0.title.lowercased().contains(lower) || $0.aliases.contains { $0.lowercased().contains(lower) } }
            .prefix(4)
            .map { PickerResult(name: $0.title, subtitle: $0.subtitle, coordinate: $0.coordinate, source: .gazetteer) }
        results = Array(gaz)

        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = q
        req.region = LocationPickerView.phRegion
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

    private func reverseGeocode(_ coord: CLLocationCoordinate2D) {
        CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: coord.latitude, longitude: coord.longitude)) { placemarks, _ in
            guard let p = placemarks?.first else { return }
            let parts = [p.subLocality ?? p.name, p.locality, p.administrativeArea].compactMap { $0 }
            // De-dupe consecutive equal components (e.g. name == locality).
            var seen = Set<String>()
            let joined = parts.filter { seen.insert($0).inserted }.joined(separator: ", ")
            // Hop to the main actor before mutating @State (Swift 6 / iOS 26).
            Task { @MainActor in address = joined }
        }
    }
}
