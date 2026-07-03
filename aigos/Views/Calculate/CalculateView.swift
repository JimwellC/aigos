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
    @AppStorage("fuelUnit") private var fuelUnit: FuelUnit = .kmPerL

    @State private var selectedVehicleID: UUID?
    @State private var origin = ""
    @State private var destination = ""
    @State private var distanceText = ""
    @State private var distanceIsEstimated = false

    @State private var acInUse = true
    @State private var roadType: RoadType = .highway
    @State private var avgHighwaySpeed: Double = 90
    @State private var avgCitySpeed: Double = 40

    @State private var showingDrivingDetails = false
    @State private var estimate: FuelEstimate?
    @State private var heroCost: Double = 0
    @State private var savedThisRoute = false
    @State private var showingVehiclePicker = false
    @State private var showingTalk = false
    @FocusState private var distanceFocused: Bool

    private let resolver: RouteResolver = GazetteerRouteResolver()

    private var selectedVehicle: VehicleProfile? {
        vehicles.first { $0.id == selectedVehicleID } ?? vehicles.first
    }

    private var distanceKm: Double? {
        Double(distanceText.trimmingCharacters(in: .whitespaces))
    }

    private var canCalculate: Bool {
        selectedVehicle != nil && (distanceKm ?? 0) > 0
    }

    var body: some View {
        ZStack {
            AigosBackground()

            ScrollView {
                VStack(spacing: Space.lg) {
                    header
                    vehicleCard
                    routeCard
                    drivingCard

                    PrimaryButton(title: "Calculate", systemImage: "bolt.fill", enabled: canCalculate, action: calculate)

                    if let estimate {
                        ResultCard(estimate: estimate, heroCost: heroCost, confidence: confidenceText)
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
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("aigos")
                    .rounded(15, weight: .semibold)
                    .foregroundStyle(Color.aigosTextSecondary)
                Text("CALCULATE")
                    .rounded(30, weight: .bold)
                    .kerning(1.5)
                    .foregroundStyle(.white)
            }
            Spacer()
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
                    .font(.system(size: 22))
                    .foregroundStyle(Color.aigosAmber)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.12), in: Circle())

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
            FieldLabel("Distance")

            // The prominent, always-editable distance field — the primary input.
            HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                TextField("0", text: $distanceText, prompt: Text("0").foregroundColor(Color.aigosTextTertiary))
                    .rounded(38, weight: .bold)
                    .foregroundStyle(.white)
                    .tint(.white)
                    .keyboardType(.decimalPad)
                    .focused($distanceFocused)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("km")
                    .rounded(20, weight: .semibold)
                    .foregroundStyle(Color.aigosTextSecondary)
                if distanceIsEstimated {
                    Text("ESTIMATED")
                        .rounded(10, weight: .bold)
                        .kerning(0.8)
                        .foregroundStyle(Color.aigosAmberDeep)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.white.opacity(0.85), in: Capsule())
                }
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.3), lineWidth: 1))

            Text("Type your trip distance, or estimate it from place names below. All distances are estimates.")
                .rounded(12)
                .foregroundStyle(Color.aigosTextTertiary)

            Divider().overlay(Color.white.opacity(0.15))

            FieldLabel("Estimate from places")
            GlassField(placeholder: "From (e.g. Manila)", text: $origin, autocap: .words)
            GlassField(placeholder: "To (e.g. Batangas)", text: $destination, autocap: .words)
            Button(action: estimateDistance) {
                Label("Estimate distance", systemImage: "map")
                    .rounded(15, weight: .semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.15), in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(origin.isEmpty || destination.isEmpty)
            .opacity(origin.isEmpty || destination.isEmpty ? 0.5 : 1)
        }
        .padding(Space.md)
        .glassCard()
        // Tapping the distance field to type means the user is entering their own
        // figure — clear the "estimated" tag.
        .onChange(of: distanceFocused) { _, focused in
            if focused { distanceIsEstimated = false }
        }
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
                    .foregroundStyle(Color.aigosAmber)
                }
            }

            if hasProfile && !showingDrivingDetails {
                // "Same as last time?" compact confirm (Section 14B)
                HStack(spacing: Space.sm) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color.aigosAmber)
                    Text(sameAsLastSummary)
                        .rounded(15, weight: .medium)
                        .foregroundStyle(.white)
                }
            } else {
                roadTypePicker
                Toggle(isOn: $acInUse) {
                    Text("Aircon on")
                        .rounded(15, weight: .medium)
                        .foregroundStyle(.white)
                }
                .tint(Color.aigosAmber)

                speedSlider(title: "Highway speed", value: $avgHighwaySpeed, range: 40...140)
                speedSlider(title: "City speed", value: $avgCitySpeed, range: 10...80)
            }
        }
        .padding(Space.md)
        .glassCard()
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
                        .rounded(14, weight: .semibold)
                        .foregroundStyle(selected ? .white : .aigosTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selected ? Color.aigosAmber : Color.white.opacity(0.12), in: Capsule())
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
                    .foregroundStyle(Color.aigosAmber)
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
        distanceText = draft.distanceKm.oneDecimal
        distanceIsEstimated = false
        if let id = draft.vehicleId, vehicles.contains(where: { $0.id == id }) {
            selectedVehicleID = id
        }
        appState.pendingDraft = nil
        DispatchQueue.main.async { calculate() }
    }

    private func estimateDistance() {
        Haptics.tap(.light)
        guard let result = resolver.route(from: origin, to: destination) else {
            distanceIsEstimated = false
            return
        }
        distanceText = result.distanceKm.oneDecimal
        distanceIsEstimated = result.isEstimated
    }

    private func calculate() {
        guard let vehicle = selectedVehicle, let distanceKm else { return }
        Haptics.tap(.medium)

        let price = PriceService.price(for: vehicle.fuelType, in: context)
        let result = CalculationEngine.estimate(
            distanceKm: distanceKm,
            baseEfficiencyKmL: vehicle.efficiencyKmL,
            fuelPricePerLitre: price,
            avgHighwaySpeedKmh: avgHighwaySpeed,
            avgCitySpeedKmh: avgCitySpeed,
            acInUse: acInUse,
            roadType: roadType
        )

        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            estimate = result
            savedThisRoute = false
        }
        // Count-up signature moment.
        heroCost = 0
        withAnimation(.snappy(duration: 0.6)) { heroCost = result.estimatedCost }

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
            acWasOn: acInUse
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
        ], inMemory: true)
}
