//
//  CalculateView.swift
//  aigos
//
//  The main trip calculator (Tab 1). Sprint-1 definition of done: pick a vehicle,
//  enter origin + destination, tap Calculate, see an estimated PHP fuel cost with
//  a full breakdown. The full "Talk to aigos" interview arrives in Sprint 3; for
//  now the driving factors are quick inline controls seeded from the vehicle's
//  DrivingProfile.
//

import SwiftUI
import SwiftData

struct CalculateView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \VehicleProfile.createdAt) private var vehicles: [VehicleProfile]

    @State private var selectedVehicleID: UUID?
    @State private var origin = ""
    @State private var destination = ""

    @State private var distanceText = ""
    @State private var distanceIsEstimated = false

    @State private var acInUse = true
    @State private var roadType: RoadType = .highway
    @State private var avgHighwaySpeed: Double = 90
    @State private var avgCitySpeed: Double = 40

    @State private var estimate: FuelEstimate?
    @State private var showingVehiclePicker = false

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
        NavigationStack {
            Form {
                vehicleSection
                routeSection
                drivingSection

                Section {
                    Button(action: calculate) {
                        Text("Calculate")
                            .frame(maxWidth: .infinity)
                            .fontWeight(.semibold)
                    }
                    .disabled(!canCalculate)
                }

                if let estimate {
                    Section {
                        ResultCard(
                            estimate: estimate,
                            fuelType: selectedVehicle?.fuelType ?? .ron95
                        )
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Calculate")
            .sheet(isPresented: $showingVehiclePicker) {
                VehiclePicker(selectedVehicleID: $selectedVehicleID)
            }
            .onAppear(perform: syncSelection)
            .onChange(of: selectedVehicleID) { _, _ in applyVehicleDefaults() }
        }
    }

    // MARK: - Sections

    private var vehicleSection: some View {
        Section("Vehicle") {
            if let vehicle = selectedVehicle {
                Button {
                    showingVehiclePicker = true
                } label: {
                    HStack {
                        Label(vehicle.name, systemImage: vehicle.type.systemImage)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(vehicle.efficiencyKmL.oneDecimal) km/L")
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                }
            } else {
                Button("Add a vehicle to get started") {
                    showingVehiclePicker = true
                }
            }
        }
    }

    private var routeSection: some View {
        Section("Route") {
            TextField("Origin (e.g. Manila)", text: $origin)
                .textInputAutocapitalization(.words)
            TextField("Destination (e.g. Batangas)", text: $destination)
                .textInputAutocapitalization(.words)

            Button("Estimate distance", action: estimateDistance)
                .disabled(origin.isEmpty || destination.isEmpty)

            HStack {
                TextField("Distance", text: $distanceText)
                    .keyboardType(.decimalPad)
                Text("km")
                    .foregroundStyle(.secondary)
            }

            if distanceIsEstimated {
                Label("Estimated distance — tap to adjust", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var drivingSection: some View {
        Section("How you'll drive") {
            Picker("Road type", selection: $roadType) {
                ForEach(RoadType.allCases) { Text($0.label).tag($0) }
            }
            Toggle("Aircon on", isOn: $acInUse)

            VStack(alignment: .leading) {
                Text("Highway speed: \(Int(avgHighwaySpeed)) km/h")
                Slider(value: $avgHighwaySpeed, in: 40...140, step: 5)
            }
            VStack(alignment: .leading) {
                Text("City speed: \(Int(avgCitySpeed)) km/h")
                Slider(value: $avgCitySpeed, in: 10...80, step: 5)
            }
        }
    }

    // MARK: - Actions

    private func syncSelection() {
        if selectedVehicleID == nil {
            selectedVehicleID = vehicles.first(where: \.isDefault)?.id ?? vehicles.first?.id
        }
        applyVehicleDefaults()
    }

    private func applyVehicleDefaults() {
        guard let profile = selectedVehicle?.drivingProfile else { return }
        avgHighwaySpeed = profile.avgHighwaySpeedKmh
        avgCitySpeed = profile.avgCitySpeedKmh
        acInUse = profile.usesACByDefault
        roadType = profile.defaultRoadType
    }

    private func estimateDistance() {
        guard let result = resolver.route(from: origin, to: destination) else {
            distanceIsEstimated = false
            return
        }
        distanceText = result.distanceKm.oneDecimal
        distanceIsEstimated = result.isEstimated
    }

    private func calculate() {
        guard let vehicle = selectedVehicle, let distanceKm else { return }

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
        estimate = result

        // Auto-save the trip snapshot so History has a record (Section 6).
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
        try? context.save()
    }
}

#Preview {
    CalculateView()
        .modelContainer(for: [
            VehicleProfile.self, DrivingProfile.self, TripRecord.self,
            SavedRoute.self, FuelPriceCache.self,
        ], inMemory: true)
}
