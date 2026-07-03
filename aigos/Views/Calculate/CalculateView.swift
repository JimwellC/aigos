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

    @State private var acInUse = true
    @State private var roadType: RoadType = .highway
    @State private var avgHighwaySpeed: Double = 90
    @State private var avgCitySpeed: Double = 40
    @State private var traffic: TrafficCondition = .light
    @State private var vehicleLoad: VehicleLoad = .light
    @State private var rushHour = false
    @State private var fuelLevel: FuelLevel = .full

    @State private var showingDrivingDetails = false
    @State private var estimate: FuelEstimate?
    @State private var heroCost: Double = 0
    @State private var savedThisRoute = false
    @State private var showingVehiclePicker = false
    @State private var showingTalk = false
    @State private var demoSearchOpen = false
    @State private var glowPulse = false

    private var selectedVehicle: VehicleProfile? {
        vehicles.first { $0.id == selectedVehicleID } ?? vehicles.first
    }

    /// Distance derived from the two selected places (nil until both are picked).
    private var distanceKm: Double? {
        guard let originKey, let destinationKey,
              let a = PlaceResolver.point(for: originKey, personalPlaces: personalPlaces),
              let b = PlaceResolver.point(for: destinationKey, personalPlaces: personalPlaces)
        else { return nil }
        return GazetteerRouteResolver.estimate(from: a, to: b).distanceKm
    }

    private var canCalculate: Bool {
        selectedVehicle != nil && distanceKm != nil
    }

    var body: some View {
        ZStack {
            AigosBackground()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: Space.lg) {
                        header
                        vehicleCard
                        routeCard
                        drivingCard

                        calculateButton

                        if let estimate {
                            ResultCard(estimate: estimate, heroCost: heroCost, confidence: confidenceText,
                                       tankLiters: selectedVehicle?.type.typicalTankLiters)
                                .id("result")
                                .transition(.move(edge: .bottom).combined(with: .opacity))

                            SecondaryButton(
                                title: savedThisRoute ? "Saved to routes" : "Save this route",
                                systemImage: savedThisRoute ? "star.fill" : "star",
                                action: saveRoute
                            )
                            .disabled(savedThisRoute)
                        }
                    }
                    .padding(.horizontal, Space.screen)
                    .padding(.top, Space.xl)
                    .padding(.bottom, Space.xxl)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: estimate) { _, e in
                    if e != nil {
                        withAnimation(.snappy) { proxy.scrollTo("result", anchor: .top) }
                    }
                }
            }
        }
        .sheet(isPresented: $showingVehiclePicker) {
            VehiclePicker(selectedVehicleID: $selectedVehicleID)
        }
        .sheet(isPresented: $showingTalk) {
            TalkToAigosView()
        }
        .onAppear(perform: onAppear)
        .onChange(of: selectedVehicleID) { _, _ in applyVehicleDefaults() }
        .onChange(of: appState.pendingDraft) { _, draft in applyDraft(draft) }
        // Editing/clearing a place resets the submit-error state.
        .onChange(of: origin) { _, _ in submitAttempted = false }
        .onChange(of: destination) { _, _ in submitAttempted = false }
    }

    private var calculateButton: some View {
        Button {
            if canCalculate {
                calculate()
            } else {
                Haptics.tap(.light)
                withAnimation(.easeOut(duration: 0.2)) { submitAttempted = true }
            }
        } label: {
            HStack(spacing: Space.sm) {
                Image(systemName: "bolt.fill")
                Text("Calculate")
            }
            .rounded(18, weight: .bold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(
                Capsule().fill(
                    LinearGradient(
                        colors: canCalculate
                            ? [Color.aigosAmberLight, Color.aigosAmber, Color.aigosAmberDeep]
                            : [Color.aigosAmber.opacity(0.4), Color.aigosAmberDeep.opacity(0.4)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
            )
            // Amber glow beneath the CTA (#E9A84C · 0.5 · r20 · y8), gently pulsing.
            .shadow(color: Color.aigosAmber.opacity(canCalculate ? (glowPulse ? 0.6 : 0.5) : 0),
                    radius: canCalculate ? (glowPulse ? 24 : 20) : 0, x: 0, y: 8)
        }
        .buttonStyle(PressableStyle())
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
                       showError: submitAttempted, startOpen: demoSearchOpen)
                .zIndex(2)   // its dropdown overlays the destination field
            routeConnector
            PlaceField(placeholder: "To (e.g. Batangas)", text: $destination,
                       selectedKey: $destinationKey, personalPlaces: personalPlaces,
                       showError: submitAttempted)
                .zIndex(1)

            if let distanceKm {
                Label("≈ \(distanceKm.oneDecimal) km (estimated)", systemImage: "map")
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

    // MARK: - Driving

    private var drivingCard: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack {
                FieldLabel("How you'll drive")
                Spacer()
                if hasProfile && !showingDrivingDetails {
                    Button("Adjust") {
                        withAnimation(.snappy) { showingDrivingDetails = true }
                    }
                    .rounded(13, weight: .semibold)
                    .foregroundStyle(.white)
                }
            }

            if hasProfile && !showingDrivingDetails {
                // "Same as last time?" compact confirm (Section 14B)
                HStack(spacing: Space.sm) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.white)
                    Text(sameAsLastSummary)
                        .rounded(15, weight: .medium)
                        .foregroundStyle(.white)
                }
            } else {
                labeled("Road type") { roadTypePicker }

                labeled("Traffic") {
                    pillRow(TrafficCondition.allCases, selection: $traffic) { $0.label }
                }
                Toggle(isOn: $rushHour) {
                    Text("Rush hour (7–9 AM, 5–8 PM)")
                        .rounded(15, weight: .medium)
                        .foregroundStyle(.white)
                }
                .tint(Color.aigosAmber)

                labeled("Passengers / load") {
                    pillRow(VehicleLoad.allCases, selection: $vehicleLoad) { $0.label }
                }

                Toggle(isOn: $acInUse) {
                    Text("Aircon on")
                        .rounded(15, weight: .medium)
                        .foregroundStyle(.white)
                }
                .tint(Color.aigosAmber)

                labeled("Fuel level") {
                    pillRow(FuelLevel.allCases, selection: $fuelLevel) { $0.label }
                }

                speedSlider(title: "Highway speed", value: $avgHighwaySpeed, range: 40...140)
                speedSlider(title: "City speed", value: $avgCitySpeed, range: 10...80)
            }
        }
        .padding(Space.md)
        .glassCard()
        // Rush hour on a city road → suggest Heavy traffic (user can still change).
        .onChange(of: rushHour) { _, on in if on, roadType == .city { traffic = .heavy } }
        .onChange(of: roadType) { _, rt in if rushHour, rt == .city { traffic = .heavy } }
    }

    private func labeled<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .rounded(11, weight: .semibold)
                .kerning(0.8)
                .foregroundStyle(Color.aigosTextTertiary)
            content()
        }
    }

    private func pillRow<T: Identifiable & Hashable>(
        _ items: [T], selection: Binding<T>, label: @escaping (T) -> String
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.sm) {
                ForEach(items) { item in
                    let on = selection.wrappedValue == item
                    Text(label(item))
                        .rounded(13, weight: on ? .bold : .semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Space.md)
                        .padding(.vertical, 8)
                        .background(on ? Color.aigosAmber : Color.white.opacity(0.25), in: Capsule())
                        .overlay(Capsule().stroke(on ? Color.clear : Color.white.opacity(0.5), lineWidth: 1))
                        .onTapGesture { Haptics.tap(.light); selection.wrappedValue = item }
                }
            }
        }
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

    private var roadTypePicker: some View {
        HStack(spacing: Space.sm) {
            ForEach(RoadType.allCases) { type in
                let selected = roadType == type
                Button {
                    Haptics.tap(.light)
                    roadType = type
                } label: {
                    Text(type.label)
                        .rounded(14, weight: selected ? .bold : .semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selected ? Color.aigosAmber : Color.white.opacity(0.25), in: Capsule())
                        .overlay(Capsule().stroke(selected ? Color.clear : Color.white.opacity(0.5), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func speedSlider(title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .rounded(15, weight: .medium)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(Int(value.wrappedValue)) km/h")
                    .rounded(15, weight: .semibold)
                    .foregroundStyle(.white)
            }
            Slider(value: value, in: range, step: 5)
                .tint(Color.aigosAmber)
        }
    }

    // MARK: - Derived

    private var hasProfile: Bool { selectedVehicle?.drivingProfile != nil }

    private var sameAsLastSummary: String {
        "\(roadType.label) · \(Int(avgHighwaySpeed)) km/h · AC \(acInUse ? "on" : "off")"
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
        if DebugSupport.lowFuel { fuelLevel = .low }
        if let q = DebugSupport.searchDemo {
            origin = q
            DispatchQueue.main.async { demoSearchOpen = true }
        }
        #endif
    }

    private func applyVehicleDefaults() {
        guard let profile = selectedVehicle?.drivingProfile else {
            showingDrivingDetails = true
            return
        }
        avgHighwaySpeed = profile.avgHighwaySpeedKmh
        avgCitySpeed = profile.avgCitySpeedKmh
        acInUse = profile.usesACByDefault
        roadType = profile.defaultRoadType
        showingDrivingDetails = false
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
        if let ac = draft.acOn { acInUse = ac }
        if let r = draft.rushHour { rushHour = r }
        if let l = draft.load { vehicleLoad = l }
        if let t = draft.traffic { traffic = t }
        if draft.traffic != nil || draft.rushHour != nil || draft.load != nil || draft.acOn != nil {
            showingDrivingDetails = true   // reveal so the user sees what was set
        }
        appState.pendingDraft = nil
        DispatchQueue.main.async { calculate() }
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
        return fuelLevel.fraction * vehicle.type.typicalTankLiters
    }

    private func calculate() {
        guard let vehicle = selectedVehicle, let distanceKm else { return }
        Haptics.tap(.medium)
        submitAttempted = false

        let price = PriceService.price(for: vehicle.fuelType, in: context)
        let result = CalculationEngine.estimate(
            distanceKm: distanceKm,
            baseEfficiencyKmL: vehicle.efficiencyKmL,
            fuelPricePerLitre: price,
            avgHighwaySpeedKmh: avgHighwaySpeed,
            avgCitySpeedKmh: avgCitySpeed,
            acInUse: acInUse,
            roadType: roadType,
            traffic: traffic,
            load: vehicleLoad,
            availableFuelLitres: availableFuelLitres
        )

        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            estimate = result
            savedThisRoute = false
        }
        // Count-up signature moment — 0 → final over ~0.8s with a gentle spring.
        heroCost = 0
        withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) { heroCost = result.estimatedCost }

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
            acWasOn: acInUse,
            traffic: traffic,
            load: vehicleLoad,
            wasRushHour: rushHour,
            fuelLevel: fuelLevel
        )
        context.insert(trip)
        if let profile = vehicle.drivingProfile {
            ProfileLearningEngine.updateProfile(profile, with: trip)
        }
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
        ], inMemory: true)
}
