//
//  AddVehicleView.swift
//  aigos
//
//  Create a vehicle and its linked DrivingProfile (Section 6, "per-vehicle
//  DrivingProfile"). Pre-filled with the spec's example so a first vehicle is one
//  tap away.
//

import SwiftUI
import SwiftData

struct AddVehicleView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var vehicles: [VehicleProfile]

    @Binding var selectedVehicleID: UUID?

    @State private var name = "My Car"
    @State private var type: VehicleType = .car
    @State private var fuelType: FuelType = .ron95
    @State private var efficiencyText = "12"

    private var efficiency: Double? {
        Double(efficiencyText.trimmingCharacters(in: .whitespaces))
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (efficiency ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $name)
                    Picker("Type", selection: $type) {
                        ForEach(VehicleType.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("Fuel type", selection: $fuelType) {
                        ForEach(FuelType.allCases) { Text($0.label).tag($0) }
                    }
                }
                Section("Efficiency") {
                    HStack {
                        TextField("km/L", text: $efficiencyText)
                            .keyboardType(.decimalPad)
                        Text("km/L")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Add Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        guard let efficiency else { return }
        let isFirst = vehicles.isEmpty
        let vehicle = VehicleProfile(
            name: name.trimmingCharacters(in: .whitespaces),
            type: type,
            fuelType: fuelType,
            efficiencyKmL: efficiency,
            isDefault: isFirst
        )
        let profile = DrivingProfile(vehicleId: vehicle.id)
        vehicle.drivingProfile = profile

        context.insert(vehicle)
        context.insert(profile)
        try? context.save()

        selectedVehicleID = vehicle.id
        dismiss()
    }
}
