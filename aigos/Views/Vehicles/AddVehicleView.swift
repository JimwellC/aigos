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
    var editing: VehicleProfile? = nil     // when set, edit this vehicle in place

    @State private var name = "My Car"
    @State private var type: VehicleType = .car
    @State private var fuelType: FuelType = .premium95
    @State private var efficiencyText = ""
    @State private var tankText = ""
    @State private var yearText = ""
    @State private var maintenance: MaintenanceStatus = .average
    @State private var makeDefault = false
    @State private var didLoad = false

    private var isEditing: Bool { editing != nil }

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

    /// Tank capacity (L) — the typed value, else the vehicle type's typical tank.
    private var tankCapacityL: Double {
        let typed = Double(tankText.trimmingCharacters(in: .whitespaces)) ?? 0
        return typed > 0 ? typed : type.typicalTankLiters
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

                        FieldLabel("Tank size (L)")
                        GlassField(placeholder: "\(Int(type.typicalTankLiters))", text: $tankText, keyboard: .decimalPad)
                        Text("Used for the fuel gauge and refuel warnings. Auto-filled when you pick a known model — adjust if your tank differs.")
                            .rounded(12)
                            .foregroundStyle(.white.opacity(0.5))
                            .fixedSize(horizontal: false, vertical: true)

                        FieldLabel("Year (optional)")
                        GlassField(placeholder: "e.g. 2018", text: $yearText, keyboard: .numberPad)
                        Text("We use this to estimate real-world efficiency based on engine wear.")
                            .rounded(12)
                            .foregroundStyle(.white.opacity(0.5))
                            .fixedSize(horizontal: false, vertical: true)

                        FieldLabel("Maintenance")
                        SelectablePillFlow(items: MaintenanceStatus.allCases, selection: $maintenance) { "\($0.emoji) \($0.label)" }

                        if isEditing || !vehicles.isEmpty {
                            Toggle(isOn: $makeDefault) {
                                Text("Set as default vehicle")
                                    .rounded(15, weight: .medium)
                                    .foregroundStyle(.white)
                            }
                            .tint(Color.aigosAmber)
                            .padding(.top, Space.xs)
                        }
                    }
                    .padding(.horizontal, Space.screen)
                    .padding(.vertical, Space.lg)
                }
            }
            .onAppear(perform: load)
            .navigationTitle(isEditing ? "Edit Vehicle" : "Add Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.aigosAmberDeep, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.tint(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save changes" : "Save", action: save)
                        .disabled(!canSave).tint(.white)
                }
            }
        }
    }

    /// Seed fields once — from the vehicle being edited, else a Talk suggestion.
    private func load() {
        guard !didLoad else { return }
        didLoad = true
        if let v = editing {
            name = v.name
            type = v.type
            fuelType = v.fuelType
            efficiencyText = fuelUnit.displayValue(fromKmL: v.efficiencyKmL).oneDecimal
            tankText = v.tankCapacityL.clean
            yearText = v.manufacturingYear.map(String.init) ?? ""
            maintenance = v.maintenanceStatus
            makeDefault = v.isDefault
        } else if let p = prefill {
            name = p.name
            type = p.vehicleType
            fuelType = p.fuelType
            if let kmL = p.efficiencyKmL { efficiencyText = fuelUnit.displayValue(fromKmL: kmL).oneDecimal }
            if let tank = p.tankCapacityL { tankText = tank.clean }   // auto-filled from the DB
            makeDefault = vehicles.isEmpty
        } else {
            makeDefault = vehicles.isEmpty
        }
        if efficiencyText.isEmpty { efficiencyText = fuelUnit.defaultInput }
    }

    private func save() {
        guard let efficiency else { return }
        Haptics.success()
        let kmL = fuelUnit.kmL(fromDisplay: efficiency)   // store canonical km/L
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        if let v = editing {
            v.name = trimmedName
            v.type = type
            v.fuelType = fuelType
            v.efficiencyKmL = kmL
            v.tankCapacityL = tankCapacityL
            v.manufacturingYear = year
            v.maintenanceStatus = maintenance
            if makeDefault {
                // Fetch-clears-sets-saves once via the single safe path.
                VehicleProfile.setAsDefault(v, context: context)
            } else {
                saveContext()
            }
            selectedVehicleID = v.id
        } else {
            let makeItDefault = makeDefault || vehicles.isEmpty
            let vehicle = VehicleProfile(
                name: trimmedName, type: type, fuelType: fuelType, efficiencyKmL: kmL,
                tankCapacityL: tankCapacityL,
                isDefault: false, manufacturingYear: year, maintenanceStatus: maintenance
            )
            let profile = DrivingProfile()
            vehicle.drivingProfile = profile
            context.insert(vehicle)
            context.insert(profile)
            if makeItDefault {
                // Clears any other default and saves once, atomically.
                VehicleProfile.setAsDefault(vehicle, context: context)
            } else {
                saveContext()
            }
            selectedVehicleID = vehicle.id
        }
        dismiss()
    }

    private func saveContext() {
        do { try context.save() } catch {
            #if DEBUG
            print("⚠️ AddVehicleView save failed: \(error)")
            #endif
        }
    }
}
