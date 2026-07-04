//
//  CalculateView.swift
//  aigos
//
//  The main trip calculator (Tab 1) — the hero screen. Glassmorphism over the
//  warm amber gradient. Pick a vehicle, enter a route, confirm "same as last
//  time?" (Section 14B) or adjust, then Calculate for a full breakdown with a
//  count-up cost. Every trip is auto-saved and folds into the self-learning
//  DrivingProfile (Section 14C).
//

import SwiftUI
import SwiftData
import MapKit

struct CalculateView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query(sort: \VehicleProfile.createdAt) private var vehicles: [VehicleProfile]
    @Query private var personalPlaces: [PersonalPlace]
    @AppStorage("fuelUnit") private var fuelUnit: FuelUnit = .kmPerL

    @State private var selectedVehicleID: UUID?
    @State private var origin = ""
    @State private var destination = ""
    @State private var originKey: String?       // non-nil once picked from suggestions
    @State private var destinationKey: String?
    @State private var submitAttempted = false

    @State private var acUsage: ACUsage = .always
    @State private var roadType: RoadType = .highway
    @State private var avgHighwaySpeed: Double = 90
    @State private var avgCitySpeed: Double = 40
    @State private var traffic: TrafficCondition = .light
    @State private var vehicleLoad: VehicleLoad = .light
    @State private var rushHour = false
    @State private var fuelLevel: FuelLevel = .full
    @State private var weather: WeatherCondition = .clear
    @State private var roadSurface: RoadSurface = .smooth

    @State private var showingDrivingSheet = false
    @State private var estimate: FuelEstimate?
    @State private var savedThisRoute = false
    @State private var showingVehiclePicker = false
    @State private var showingTalk = false
    @State private var showingAddVehicle = false
    @State private var addVehiclePrefill: VehicleDraft?
    @State private var demoSearchOpen = false
    @State private var glowPulse = false

    // Loading + result sheet
    @State private var isCalculating = false
    @State private var showingResult = false
    @State private var resultRouteTitle = ""
    @State private var resultVehicleName = ""

    // Precise road distance (MKDirections, online only)
    @State private var preciseDistanceKm: Double?
    @State private var routeIsPrecise = false
    @State private var routeCoordinates: [CLLocationCoordinate2D]?   // actual road polyline
    @State private var detectedRoad: RouteAnalyzer.Suggestion?       // auto-detected road type

    // GPS trip tracking (v1.1)
    @State private var tracker = TripTracker.shared
    @State private var lastTrip: TripRecord?
    @State private var lastSummary: TripSummary?
    @State private var showingComparison = false
    @State private var showingTrackDenied = false
    @State private var trackEstDistance: Double = 0
    @State private var trackEstFuel: Double = 0
    @State private var trackEstCost: Double = 0
    @State private var trackRatedKmL: Double = 12

    private var selectedVehicle: VehicleProfile? {
        vehicles.first { $0.id == selectedVehicleID } ?? vehicles.first
    }

    private var originPoint: GeoPoint? {
        originKey.flatMap { PlaceResolver.point(for: $0, personalPlaces: personalPlaces) }
    }
    private var destinationPoint: GeoPoint? {
        destinationKey.flatMap { PlaceResolver.point(for: $0, personalPlaces: personalPlaces) }
    }

    /// Distance between the two selected places. Uses the precise MKDirections road
    /// distance when available (online), else the gazetteer haversine estimate.
    private var distanceKm: Double? {
        if let preciseDistanceKm { return preciseDistanceKm }
        guard let a = originPoint, let b = destinationPoint else { return nil }
        return GazetteerRouteResolver.estimate(from: a, to: b).distanceKm
    }

    private var canCalculate: Bool {
        selectedVehicle != nil && distanceKm != nil && !crossIsland
    }

    /// True when the two picked places are on different islands (a sea/air trip)
    /// — a continuous land distance would be meaningless. Only meaningful once
    /// both places are chosen from the gazetteer.
    private var crossIsland: Bool {
        guard originKey != nil, destinationKey != nil else { return false }
        return IslandResolver.isCrossIsland(origin, destination)
    }

    private var mapPickerDebug: Bool {
        #if DEBUG
        return DebugSupport.mapPicker
        #else
        return false
        #endif
    }

    var body: some View {
        ZStack(alignment: .top) {
            AigosBackground(mascotPeek: CGSize(width: 60, height: -70))

            ScrollView {
                VStack(spacing: Space.lg) {
                    Color.clear.frame(height: tracker.isTracking ? 220 : 0)   // room for the banner
                    header
                    vehicleCard
                    routeCard
                    drivingCard
                    calculateButton
                }
                .padding(.horizontal, Space.screen)
                .padding(.top, Space.xl)
                .padding(.bottom, Space.xxl)
            }
            .scrollDismissesKeyboard(.interactively)

            if tracker.isTracking {
                TripTrackingBanner(tracker: tracker, onEnd: endTracking)
                    .padding(.horizontal, Space.screen)
                    .padding(.top, Space.md)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4), value: tracker.isTracking)
        .sheet(isPresented: $showingComparison) {
            if let s = lastSummary {
                TripComparisonView(
                    summary: s,
                    estDistanceKm: trackEstDistance,
                    estFuelL: trackEstFuel, estCostPHP: trackEstCost,
                    vehicleName: tracker.vehicleName,
                    ratedKmL: trackRatedKmL,
                    onUpdateProfile: updateEfficiency, onKeep: {})
            }
        }
        .alert("Location needed", isPresented: $showingTrackDenied) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Allow \u{201C}Always\u{201D} location in Settings to track your trip, or just drop pins as usual.")
        }
        .sheet(isPresented: $showingVehiclePicker) {
            VehiclePicker(selectedVehicleID: $selectedVehicleID)
        }
        .sheet(isPresented: $showingTalk) {
            TalkToAigosView()
        }
        .sheet(isPresented: $showingAddVehicle) {
            AddVehicleView(selectedVehicleID: $selectedVehicleID, prefill: addVehiclePrefill)
        }
        .sheet(isPresented: $showingDrivingSheet) {
            DrivingSheet(
                highwaySpeed: $avgHighwaySpeed,
                citySpeed: $avgCitySpeed,
                acUsage: $acUsage,
                roadType: $roadType,
                traffic: $traffic,
                load: $vehicleLoad,
                rushHour: $rushHour,
                fuelLevel: $fuelLevel,
                weather: $weather,
                roadSurface: $roadSurface
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground { AigosBackground() }
        }
        .sheet(isPresented: $showingResult) {
            if let estimate {
                ResultSheet(
                    estimate: estimate,
                    finalCost: estimate.estimatedCost,
                    confidence: confidenceText,
                    tankLiters: selectedVehicle?.tankCapacityL,
                    routeTitle: resultRouteTitle,
                    vehicleName: resultVehicleName,
                    saved: $savedThisRoute,
                    onSave: saveRoute,
                    onTrack: startTracking,
                    onDone: { showingResult = false }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground { AigosBackground() }
            }
        }
        .onAppear(perform: onAppear)
        .onChange(of: selectedVehicleID) { _, _ in applyVehicleDefaults() }
        .onChange(of: appState.pendingDraft) { _, draft in applyDraft(draft) }
        .onChange(of: appState.pendingVehicleDraft) { _, draft in
            guard let draft else { return }
            addVehiclePrefill = draft
            appState.pendingVehicleDraft = nil
            // Let the Talk sheet finish dismissing before presenting Add Vehicle.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showingAddVehicle = true }
        }
        // Editing/clearing a place resets the submit-error state.
        .onChange(of: origin) { _, _ in submitAttempted = false }
        .onChange(of: destination) { _, _ in submitAttempted = false }
        .onChange(of: originKey) { _, _ in updatePreciseDistance() }
        .onChange(of: destinationKey) { _, _ in updatePreciseDistance() }
    }

    /// Ask Apple Maps for the real road distance (online). Falls back silently to
    /// the gazetteer estimate when offline or when no route is found.
    private func updatePreciseDistance() {
        preciseDistanceKm = nil
        routeIsPrecise = false
        routeCoordinates = nil
        detectedRoad = nil
        guard let a = originPoint, let b = destinationPoint else { return }
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: a.clCoordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: b.clCoordinate))
        request.transportType = .automobile
        MKDirections(request: request).calculate { response, _ in
            guard let route = response?.routes.first, route.distance.isFinite else { return }
            // Capture route data off the actor, then hop to the main actor before
            // touching @State — the completion is @Sendable (Swift 6 / iOS 26).
            let metres = route.distance
            let coords = route.polyline.coordinates
            let steps = route.steps.map(\.instructions).filter { !$0.isEmpty }
            let name = route.name
            Task { @MainActor in
                preciseDistanceKm = metres / 1000.0
                routeIsPrecise = true
                routeCoordinates = coords
                applyRouteDetection(stepTexts: steps, routeName: name)
            }
        }
    }

    /// Auto-detect the road type from the online route and pre-select it. The user
    /// can still override in the "How you'll drive" sheet.
    private func applyRouteDetection(stepTexts: [String], routeName: String) {
        let oProv = GazetteerRouteResolver.entry(for: origin)?.subtitle
        let dProv = GazetteerRouteResolver.entry(for: destination)?.subtitle
        guard let result = RouteAnalyzer.detect(
            stepTexts: stepTexts, routeName: routeName,
            origin: origin, destination: destination,
            originProvince: oProv, destinationProvince: dProv) else { return }
        detectedRoad = result
        roadType = result.roadType
    }

    private var calculateButton: some View {
        // `live` = actionable or mid-calc; the glow only pulses when it's idle and
        // ready to tap (draws the eye), and holds steady while calculating.
        let live = canCalculate || isCalculating
        let idlePulse = canCalculate && !isCalculating
        return Button {
            if isCalculating { return }
            if canCalculate {
                startCalculate()
            } else {
                Haptics.tap(.light)
                withAnimation(.easeOut(duration: 0.2)) { submitAttempted = true }
            }
        } label: {
            HStack(spacing: Space.sm) {
                if isCalculating {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .controlSize(.small)
                    Text("Calculating…")
                } else {
                    Image(systemName: "bolt.fill")
                    Text("Calculate")
                }
            }
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            // Deep brown pill so white text/icon pop against the amber background.
            .background(
                Capsule().fill(
                    LinearGradient(colors: [Color(hex: "#8A4E24"), Color(hex: "#6B3A1A")],
                                   startPoint: .top, endPoint: .bottom)
                )
            )
            .overlay(Capsule().strokeBorder(Color.aigosAmberLight.opacity(0.5), lineWidth: 1.5))
            .clipShape(Capsule())
            // Warm amber glow beneath; pulses outward when idle + ready.
            .shadow(color: Color(hex: "#C4793A").opacity(live ? 0.6 : 0),
                    radius: !live ? 0 : (idlePulse ? (glowPulse ? 30 : 18) : 22),
                    x: 0, y: 8)
            .opacity(live ? 1.0 : 0.45)
        }
        .buttonStyle(PressableStyle())     // scales to 0.96 with spring on press
        .disabled(isCalculating)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { glowPulse = true }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Space.md) {
            MascotView(size: 44)
            VStack(alignment: .leading, spacing: 0) {
                Text("aigos")
                    .rounded(14, weight: .semibold)
                    .foregroundStyle(Color.white.opacity(0.7))
                Text("CALCULATE")
                    .screenTitle()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Spacer(minLength: Space.sm)
            Button {
                Haptics.tap(.light)
                showingTalk = true
            } label: {
                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(Color.white.opacity(0.14), in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Talk to aigos")
        }
    }

    // MARK: - Vehicle

    private var vehicleCard: some View {
        Button {
            Haptics.tap(.light)
            showingVehiclePicker = true
        } label: {
            HStack(spacing: Space.md) {
                Image(systemName: selectedVehicle?.type.systemImage ?? "car.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.aigosAmber.opacity(0.9), in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1.5))

                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedVehicle?.name ?? "Add a vehicle")
                        .rounded(17, weight: .semibold)
                        .foregroundStyle(.white)
                    if let vehicle = selectedVehicle {
                        Text("\(vehicle.fuelType.label) · \(fuelUnit.format(kmL: vehicle.efficiencyKmL))")
                            .rounded(13)
                            .foregroundStyle(Color.aigosTextSecondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.aigosTextTertiary)
            }
            .padding(Space.md)
            .glassCard()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Route

    private var routeCard: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            FieldLabel("Route")

            PlaceField(placeholder: "From (e.g. Manila)", text: $origin,
                       selectedKey: $originKey, personalPlaces: personalPlaces,
                       showError: submitAttempted, startOpen: demoSearchOpen,
                       startMapOpen: mapPickerDebug)
                .zIndex(2)   // its dropdown overlays the destination field
            routeConnector
            PlaceField(placeholder: "To (e.g. Batangas)", text: $destination,
                       selectedKey: $destinationKey, personalPlaces: personalPlaces,
                       showError: submitAttempted)
                .zIndex(1)

            if crossIsland {
                crossIslandBanner
            } else if let distanceKm, let a = originPoint, let b = destinationPoint {
                RoutePreview(origin: a, destination: b, precise: routeIsPrecise,
                             routeCoordinates: routeCoordinates)
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.2), lineWidth: 1))

                HStack(spacing: 6) {
                    Image(systemName: routeIsPrecise ? "map.fill" : "map")
                    Text(routeIsPrecise
                         ? "\(distanceKm.oneDecimal) km · via Apple Maps"
                         : "≈ \(distanceKm.oneDecimal) km · estimated")
                }
                .rounded(14, weight: .semibold)
                .foregroundStyle(.white.opacity(0.9))

                if let detected = detectedRoad {
                    routeDetectionBanner(detected)
                }
            } else if distanceKm != nil {
                Label("≈ \(distanceKm!.oneDecimal) km (estimated)", systemImage: "map")
                    .rounded(14, weight: .semibold)
                    .foregroundStyle(.white.opacity(0.9))
            } else {
                Text("Pick both places from the suggestions to estimate the distance.")
                    .rounded(12)
                    .foregroundStyle(Color.white.opacity(0.6))
            }
        }
        .padding(Space.md)
        .glassCard()
    }

    /// Shown when the two places are on different islands — a land distance would
    /// be meaningless, so we block Calculate and point to the sea/air breakdown.
    private var crossIslandBanner: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.sm) {
                Image(systemName: "ferry.fill").foregroundStyle(.white)
                Text("Sea or air travel required")
                    .rounded(16, weight: .bold)
                    .foregroundStyle(.white)
            }
            Text("\(destination) is on a separate island — this isn't a direct land route. Ask aigos for the land portion plus typical flight and ferry costs.")
                .rounded(13)
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            Button {
                Haptics.tap(.light)
                showingTalk = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left.and.text.bubble.right.fill")
                    Text("See sea / air options")
                }
                .rounded(14, weight: .semibold)
                .foregroundStyle(Color.aigosAmberDeep)
                .padding(.horizontal, Space.md)
                .padding(.vertical, 10)
                .background(.white, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.aigosAmberDeep.opacity(0.92), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// Banner shown when the online route auto-selected a road type. The user can
    /// still override it in the "How you'll drive" sheet.
    private func routeDetectionBanner(_ s: RouteAnalyzer.Suggestion) -> some View {
        HStack(spacing: Space.sm) {
            Image(systemName: s.roadType == .mountain ? "mountain.2.fill"
                            : s.roadType == .city ? "building.2.fill" : "road.lanes")
                .foregroundStyle(.white)
            Text("Route detected: \(s.label) — using \(s.roadType.label.lowercased()) factors")
                .rounded(13, weight: .medium)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(Space.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.aigosAmber.opacity(0.22), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.aigosAmber.opacity(0.5), lineWidth: 1))
    }

    // MARK: - Driving

    private var drivingCard: some View {
        Button {
            Haptics.tap(.light)
            showingDrivingSheet = true
        } label: {
            VStack(alignment: .leading, spacing: Space.sm) {
                HStack {
                    FieldLabel("How you'll drive")
                    Spacer()
                    Text("Adjust")
                        .rounded(13, weight: .semibold)
                        .foregroundStyle(.white)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }

                HStack(spacing: Space.sm) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.white)
                    Text(drivingSummary)
                        .rounded(15, weight: .medium)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Space.md)
            .glassCard()
        }
        .buttonStyle(.plain)
    }

    /// Amber origin→destination route connector (dot · dashed · pin).
    private var routeConnector: some View {
        HStack(spacing: Space.sm) {
            HStack(spacing: 6) {
                Circle().fill(Color.white).frame(width: 8, height: 8)
                ForEach(0..<6, id: \.self) { _ in
                    Circle().fill(Color.white.opacity(0.8)).frame(width: 4, height: 4)
                }
                Image(systemName: "location.north.fill")
                    .rotationEffect(.degrees(135))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
            Spacer()
        }
        .padding(.leading, Space.sm)
        .frame(height: 14)
    }

    // MARK: - Derived

    private var acOn: Bool { acUsage.isOn }

    /// Compact one-line summary shown on the driving card (truncates with "…").
    private var drivingSummary: String {
        var parts = ["\(roadType.label) · \(Int(avgHighwaySpeed)) km/h", "AC \(acOn ? "on" : "off")"]
        if traffic != .light { parts.append("\(traffic.label) traffic") }
        if vehicleLoad != .light { parts.append(vehicleLoad.label) }
        return parts.joined(separator: " · ")
    }

    private var confidenceText: String? {
        guard let profile = selectedVehicle?.drivingProfile, profile.tripCount > 0 else { return nil }
        return "\(profile.confidenceLevel.label) · \(profile.tripCount) trip\(profile.tripCount == 1 ? "" : "s")"
    }

    // MARK: - Actions

    private func onAppear() {
        if selectedVehicleID == nil {
            selectedVehicleID = vehicles.first(where: \.isDefault)?.id ?? vehicles.first?.id
        }
        applyVehicleDefaults()
        applyDraft(appState.pendingDraft)
        #if DEBUG
        if DebugSupport.autoOpenTalk { showingTalk = true }
        if DebugSupport.autoOpenDriving { showingDrivingSheet = true }
        if DebugSupport.routePreview {
            origin = "Manila"; originKey = exactKey(for: "Manila")
            destination = "Batangas"; destinationKey = exactKey(for: "Batangas")
            updatePreciseDistance()
        }
        if DebugSupport.lowFuel { fuelLevel = .low }
        if DebugSupport.vehiclesPicker { DispatchQueue.main.async { showingVehiclePicker = true } }
        if let q = DebugSupport.searchDemo {
            origin = q
            DispatchQueue.main.async { demoSearchOpen = true }
        }
        #endif
    }

    private func applyVehicleDefaults() {
        guard let profile = selectedVehicle?.drivingProfile else { return }
        avgHighwaySpeed = profile.avgHighwaySpeedKmh
        avgCitySpeed = profile.avgCitySpeedKmh
        acUsage = profile.usesACByDefault ? .always : .off
        roadType = profile.defaultRoadType
    }

    private func applyDraft(_ draft: CalculatorDraft?) {
        guard let draft else { return }
        origin = draft.origin
        destination = draft.destination
        originKey = exactKey(for: draft.origin)
        destinationKey = exactKey(for: draft.destination)
        if let id = draft.vehicleId, vehicles.contains(where: { $0.id == id }) {
            selectedVehicleID = id
        }
        // Conditions understood by Talk to aigos.
        if let ac = draft.acOn { acUsage = ac ? .always : .off }
        if let r = draft.rushHour { rushHour = r }
        if let l = draft.load { vehicleLoad = l }
        if let t = draft.traffic { traffic = t }
        appState.pendingDraft = nil
        DispatchQueue.main.async { startCalculate() }
    }

    /// Resolve a place name to a selection key (personal name or gazetteer key),
    /// used when a Saved route or Talk to aigos hands over a prefilled route.
    private func exactKey(for name: String) -> String? {
        PlaceSearch.exactKey(name, personalPlaces: personalPlaces)
            ?? GazetteerRouteResolver.entry(for: name)?.key
    }

    /// Litres currently in the tank, used only for the low-fuel warning.
    private var availableFuelLitres: Double? {
        guard let vehicle = selectedVehicle else { return nil }
        return fuelLevel.fraction * vehicle.tankCapacityL
    }

    /// Kick off a calculation: show the loading state, compute immediately, then
    /// reveal the result sheet after a minimum 1.2s so it feels considered.
    private func startCalculate() {
        guard canCalculate, !isCalculating else { return }
        Haptics.tap(.medium)   // medium impact on press
        submitAttempted = false
        withAnimation(.easeInOut(duration: 0.25)) { isCalculating = true }

        performCalculation()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            guard isCalculating else { return }   // user may have navigated away
            Haptics.tap(.medium)
            withAnimation(.easeOut(duration: 0.2)) { isCalculating = false }
            showingResult = true
        }
    }

    private func performCalculation() {
        // Defensive: never proceed without a vehicle and a FINITE distance. A NaN
        // or infinite distance would later trap in Int()/gauge rendering.
        guard let vehicle = selectedVehicle,
              let distanceKm, distanceKm.isFinite, distanceKm >= 0 else { return }

        resultRouteTitle = "\(origin.isEmpty ? "Trip" : origin) → \(destination.isEmpty ? "Destination" : destination)"
        resultVehicleName = vehicle.name

        let price = PriceService.price(for: vehicle.fuelType, in: context)
        let result = CalculationEngine.estimate(
            distanceKm: distanceKm,
            baseEfficiencyKmL: vehicle.efficiencyKmL,
            fuelPricePerLitre: price,
            avgHighwaySpeedKmh: avgHighwaySpeed,
            avgCitySpeedKmh: avgCitySpeed,
            acInUse: acOn,
            roadType: roadType,
            traffic: traffic,
            load: vehicleLoad,
            availableFuelLitres: availableFuelLitres,
            acUsage: acUsage,       // real 3-state factor (Always/Sometimes/Off)
            ageYears: vehicle.ageYears(),
            maintenance: vehicle.maintenanceStatus,
            weather: weather,
            roadSurface: roadSurface
        )

        estimate = result
        savedThisRoute = false

        // Auto-save the trip snapshot and fold it into the self-learning profile.
        let trip = TripRecord(
            origin: origin.isEmpty ? "—" : origin,
            destination: destination.isEmpty ? "—" : destination,
            vehicleName: vehicle.name,
            fuelType: vehicle.fuelType,
            estimate: result,
            avgHighwaySpeed: avgHighwaySpeed,
            avgCitySpeed: avgCitySpeed,
            roadType: roadType,
            acWasOn: acOn,
            traffic: traffic,
            load: vehicleLoad,
            wasRushHour: rushHour,
            fuelLevel: fuelLevel
        )
        context.insert(trip)
        lastTrip = trip                      // reference for "Track This Trip"
        if let profile = vehicle.drivingProfile {
            ProfileLearningEngine.updateProfile(profile, with: trip)
        }
        try? context.save()
    }

    // MARK: - GPS trip tracking (v1.1)

    private func startTracking() {
        guard let vehicle = selectedVehicle, let trip = lastTrip, let est = estimate else { return }
        trackEstDistance = est.distanceKm
        trackEstFuel = est.adjustedLitres
        trackEstCost = est.estimatedCost
        trackRatedKmL = vehicle.efficiencyKmL
        let destCoord = destinationPoint.map {
            CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)
        }
        tracker.start(
            tripRecordId: trip.id,
            origin: origin.isEmpty ? "Start" : origin,
            destination: destination.isEmpty ? "Destination" : destination,
            vehicleName: vehicle.name,
            efficiencyKmL: vehicle.efficiencyKmL,
            pricePerLitre: est.fuelPricePerLitre,
            estDistanceKm: est.distanceKm,
            destinationCoord: destCoord)
        showingResult = false
        if tracker.status == .denied { showingTrackDenied = true }
    }

    private func endTracking() {
        guard tracker.isTracking else { return }
        let summary = tracker.finish()
        Haptics.tap(.medium)
        if let trip = lastTrip {
            let tracked = TrackedTrip(
                tripRecordId: trip.id, estimatedDistanceKm: trackEstDistance,
                estimatedFuelL: trackEstFuel, estimatedCostPHP: trackEstCost,
                vehicleName: tracker.vehicleName, origin: tracker.origin, destination: tracker.destination)
            tracked.routeCoordinates = summary.routeFlat
            tracked.actualDistanceKm = summary.actualDistanceKm
            tracked.actualDurationSeconds = summary.actualDurationSeconds
            tracked.actualAvgSpeedKmh = summary.actualAvgSpeedKmh
            tracked.actualFuelL = summary.actualFuelL
            tracked.actualCostPHP = summary.actualCostPHP
            tracked.accuracyPercent = summary.accuracyPercent
            tracked.startedAt = summary.startedAt
            tracked.endedAt = summary.endedAt
            tracked.isCompleted = true
            trip.isTracked = true
            context.insert(tracked)
            try? context.save()
        }
        lastSummary = summary
        showingComparison = true
    }

    /// Self-correct the vehicle's efficiency toward the value implied by the tracked
    /// drive (the comparison view already moderated/clamped it).
    private func updateEfficiency(_ newKmL: Double) {
        guard let vehicle = selectedVehicle else { return }
        vehicle.efficiencyKmL = newKmL
        vehicle.drivingProfile?.lastUpdated = Date()
        try? context.save()
    }

    private func saveRoute() {
        guard let vehicle = selectedVehicle, let distanceKm else { return }
        Haptics.tap(.light)
        let route = SavedRoute(
            name: "\(origin.isEmpty ? "Trip" : origin) → \(destination.isEmpty ? "Destination" : destination)",
            origin: origin,
            destination: destination,
            distanceKm: distanceKm,
            defaultVehicleId: vehicle.id
        )
        context.insert(route)
        try? context.save()
        withAnimation { savedThisRoute = true }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            VehicleProfile.self, DrivingProfile.self, TripRecord.self,
            SavedRoute.self, FuelPriceCache.self,
            PersonalPlace.self,
            TrackedTrip.self,
            FuelLog.self,
        ], inMemory: true)
}
