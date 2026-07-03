//
//  AddVehicleView.swift
//  aigos
//
//  Create a vehicle and its linked DrivingProfile (Feature 04). Pre-filled with
//  the spec's example so a first vehicle is one tap away.
//

import SwiftUI
import SwiftData

struct AddVehicleView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var vehicles: [VehicleProfile]
    @AppStorage("fuelUnit") private var fuelUnit: FuelUnit = .kmPerL

    @Binding var selectedVehicleID: UUID?

    @State private var name = "My Car"
    @State private var type: VehicleType = .car
    @State private var fuelType: FuelType = .ron95
    @State private var efficiencyText = ""

    private var efficiency: Double? {
        Double(efficiencyText.trimmingCharacters(in: .whitespaces))
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (efficiency ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AigosBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: Space.md) {
                        FieldLabel("Name")
                        GlassField(placeholder: "My Car", text: $name, autocap: .words)

                        FieldLabel("Type")
                        SelectablePillFlow(items: VehicleType.allCases, selection: $type) { $0.label }

                        FieldLabel("Fuel type")
                        SelectablePillFlow(items: FuelType.allCases, selection: $fuelType) { $0.label }

                        FieldLabel("Efficiency (\(fuelUnit.label))")
                        GlassField(placeholder: fuelUnit.defaultInput, text: $efficiencyText, keyboard: .decimalPad)
                    }
                    .padding(.horizontal, Space.screen)
                    .padding(.vertical, Space.lg)
                }
            }
            .onAppear { if efficiencyText.isEmpty { efficiencyText = fuelUnit.defaultInput } }
            .navigationTitle("Add Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.aigosBGTop, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.tint(Color.aigosAmberDeep)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!canSave).tint(Color.aigosAmberDeep)
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
            efficiencyKmL: fuelUnit.kmL(fromDisplay: efficiency),   // store canonical km/L
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
