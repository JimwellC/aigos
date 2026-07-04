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
    var prefill: VehicleDraft? = nil

    @State private var name = "My Car"
    @State private var type: VehicleType = .car
    @State private var fuelType: FuelType = .premium95
    @State private var efficiencyText = ""
    @State private var yearText = ""
    @State private var maintenance: MaintenanceStatus = .average

    private var efficiency: Double? {
        Double(efficiencyText.trimmingCharacters(in: .whitespaces))
    }

    private var currentYear: Int { Calendar.current.component(.year, from: Date()) }

    /// A valid manufacturing year (1990…current) or nil (no age modifier applied).
    private var year: Int? {
        guard let y = Int(yearText.trimmingCharacters(in: .whitespaces)),
              (1990...currentYear).contains(y) else { return nil }
        return y
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

                        FieldLabel("Year (optional)")
                        GlassField(placeholder: "e.g. 2018", text: $yearText, keyboard: .numberPad)
                        Text("We use this to estimate real-world efficiency based on engine wear.")
                            .rounded(12)
                            .foregroundStyle(.white.opacity(0.5))
                            .fixedSize(horizontal: false, vertical: true)

                        FieldLabel("Maintenance")
                        SelectablePillFlow(items: MaintenanceStatus.allCases, selection: $maintenance) { "\($0.emoji) \($0.label)" }
                    }
                    .padding(.horizontal, Space.screen)
                    .padding(.vertical, Space.lg)
                }
            }
            .onAppear(perform: applyPrefill)
            .navigationTitle("Add Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.aigosAmberDeep, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.tint(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!canSave).tint(.white)
                }
            }
        }
    }

    /// Seed fields from a Talk to aigos suggestion (once, on first appear).
    private func applyPrefill() {
        if let p = prefill {
            name = p.name
            type = p.vehicleType
            fuelType = p.fuelType
            if let kmL = p.efficiencyKmL, efficiencyText.isEmpty {
                efficiencyText = fuelUnit.displayValue(fromKmL: kmL).oneDecimal
            }
        }
        if efficiencyText.isEmpty { efficiencyText = fuelUnit.defaultInput }
    }

    private func save() {
        guard let efficiency else { return }
        let isFirst = vehicles.isEmpty
        let vehicle = VehicleProfile(
            name: name.trimmingCharacters(in: .whitespaces),
            type: type,
            fuelType: fuelType,
            efficiencyKmL: fuelUnit.kmL(fromDisplay: efficiency),   // store canonical km/L
            isDefault: isFirst,
            manufacturingYear: year,
            maintenanceStatus: maintenance
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
