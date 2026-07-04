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
    @State private var showingForm = false     // false = database search step (new vehicles)
    @State private var selectedModel: String?  // the picked DB model (for the checkmark)

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

                if showingForm {
                    formScroll
                } else {
                    VehicleSearchStep(
                        heading: "Search your vehicle",
                        selectedDisplayName: selectedModel,
                        onSelect: { applyEntry($0); withAnimation { showingForm = true } },
                        onManual: { applyManual(query: $0); withAnimation { showingForm = true } }
                    )
                }
            }
            .onAppear(perform: load)
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.aigosAmberDeep, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.tint(.white)
                }
                if showingForm {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(isEditing ? "Save changes" : "Save", action: save)
                            .disabled(!canSave).tint(.white)
                    }
                }
            }
        }
    }

    private var navTitle: String {
        if !showingForm { return "Add Vehicle" }
        return isEditing ? "Edit Vehicle" : "Vehicle details"
    }

    private var formScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.md) {
                // Jump back to the database search (change the picked model).
                Button {
                    withAnimation { showingForm = false }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                        Text((isEditing || selectedModel != nil) ? "Change vehicle model" : "Search the vehicle database")
                    }
                    .rounded(14, weight: .semibold)
                    .foregroundStyle(.white)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.12), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Group {
                    FieldLabel("Name")
                    GlassField(placeholder: "My Car", text: $name, autocap: .words)

                    FieldLabel("Type")
                        SelectablePillFlow(items: VehicleType.allCases, selection: $type) { $0.label }

                        FieldLabel("Fuel type")
                        SelectablePillFlow(items: FuelType.allCases, selection: $fuelType) { $0.label }

                        FieldLabel("Efficiency (\(fuelUnit.label))")
                        GlassField(placeholder: fuelUnit.defaultInput, text: $efficiencyText, keyboard: .decimalPad)
                        if selectedModel == nil {
                            Text("You can find your km/L in the car manual or at fuelly.com.")
                                .rounded(12)
                                .foregroundStyle(.white.opacity(0.5))
                                .fixedSize(horizontal: false, vertical: true)
                        }

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
                }   // end Group
            }
            .padding(.horizontal, Space.screen)
            .padding(.vertical, Space.lg)
        }
    }

    /// Seed fields once. Editing or a Talk suggestion goes straight to the form;
    /// a fresh add starts on the database search step.
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
            showingForm = true                 // edit: straight to the form
        } else if let p = prefill {
            name = p.name
            type = p.vehicleType
            fuelType = p.fuelType
            if let kmL = p.efficiencyKmL { efficiencyText = fuelUnit.displayValue(fromKmL: kmL).oneDecimal }
            if let tank = p.tankCapacityL { tankText = tank.clean }   // auto-filled from the DB
            makeDefault = vehicles.isEmpty
            selectedModel = p.name
            showingForm = true                 // Talk already picked → form
        } else {
            makeDefault = vehicles.isEmpty
            showingForm = false                // fresh add → database search first
        }
        if efficiencyText.isEmpty { efficiencyText = fuelUnit.defaultInput }
    }

    /// Auto-fill the form from a database selection.
    private func applyEntry(_ entry: VehicleEntry) {
        selectedModel = entry.displayName
        name = entry.model                     // "Vios" — the user can rename to "My Vios"
        type = entry.vehicleType
        fuelType = entry.fuelType
        efficiencyText = fuelUnit.displayValue(fromKmL: entry.kmL).oneDecimal
        tankText = entry.tankCapacityL.clean
    }

    /// Fall back to manual entry ("My car is not in the list").
    private func applyManual(query: String) {
        selectedModel = nil
        name = ""                              // user names it
        efficiencyText = fuelUnit.defaultInput // a sensible starting point to adjust
        tankText = ""                          // placeholder shows the type default
        yearText = ""
        maintenance = .average
    }

    private func save() {
        guard let efficiency else { return }
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
