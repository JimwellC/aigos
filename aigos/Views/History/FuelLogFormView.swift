//
//  FuelLogFormView.swift
//  aigos
//
//  Log a gas-up (v1.1). Full-tank logs with odometer readings power the real
//  fill-to-fill km/L. Presented as a sheet from History or Talk ("I just filled up").
//

import SwiftUI
import SwiftData

/// Pre-fill values parsed from a Talk message ("I filled up 35L at Shell for 2520").
struct FuelLogDraft: Equatable {
    var liters: Double?
    var totalCost: Double?
    var stationName: String?
}

struct FuelLogFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \VehicleProfile.createdAt) private var vehicles: [VehicleProfile]

    var prefill: FuelLogDraft? = nil

    @State private var date = Date()
    @State private var vehicleID: UUID?
    @State private var stationName = ""
    @State private var litersText = ""
    @State private var costText = ""
    @State private var odometerText = ""
    @State private var isFullTank = true
    @State private var notes = ""
    @State private var didLoad = false

    private var vehicle: VehicleProfile? {
        vehicles.first { $0.id == vehicleID } ?? vehicles.first(where: \.isDefault) ?? vehicles.first
    }
    private var liters: Double { Double(litersText.trimmingCharacters(in: .whitespaces)) ?? 0 }
    private var cost: Double { Double(costText.trimmingCharacters(in: .whitespaces)) ?? 0 }
    private var pricePerL: Double { liters > 0 ? cost / liters : 0 }
    private var canSave: Bool { vehicle != nil && liters > 0 && cost > 0 }

    var body: some View {
        NavigationStack {
            ZStack {
                AigosBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.md) {
                        FieldLabel("Date")
                        DatePicker("", selection: $date, displayedComponents: .date)
                            .datePickerStyle(.compact).labelsHidden().tint(Color.aigosAmber)
                            .colorScheme(.dark)

                        if let v = vehicle {
                            FieldLabel("Vehicle")
                            Text("\(v.name) · \(v.fuelType.label)")
                                .rounded(15, weight: .medium).foregroundStyle(.white)
                                .padding(Space.md).frame(maxWidth: .infinity, alignment: .leading).glassCard()
                        }

                        FieldLabel("Station (optional)")
                        GlassField(placeholder: "e.g. Shell Dau", text: $stationName, autocap: .words)

                        FieldLabel("Litres purchased")
                        GlassField(placeholder: "35", text: $litersText, keyboard: .decimalPad)

                        FieldLabel("Total cost (PHP)")
                        GlassField(placeholder: "2520", text: $costText, keyboard: .decimalPad)

                        if pricePerL > 0 {
                            Text("≈ PHP \(pricePerL.oneDecimal)/L")
                                .rounded(13).foregroundStyle(Color.aigosAmberLight)
                        }

                        FieldLabel("Odometer (km, optional)")
                        GlassField(placeholder: "45680", text: $odometerText, keyboard: .decimalPad)
                        Text("Add the odometer on full tanks to unlock your real km/L.")
                            .rounded(12).foregroundStyle(.white.opacity(0.5)).fixedSize(horizontal: false, vertical: true)

                        Toggle(isOn: $isFullTank) {
                            Text("Filled to full").rounded(15, weight: .medium).foregroundStyle(.white)
                        }.tint(Color.aigosAmber)

                        FieldLabel("Notes (optional)")
                        GlassField(placeholder: "e.g. long drive to Baguio", text: $notes)
                    }
                    .padding(.horizontal, Space.screen).padding(.vertical, Space.lg)
                }
            }
            .navigationTitle("Log Fuel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.aigosAmberDeep, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.tint(.white) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!canSave).tint(.white)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        vehicleID = (vehicles.first(where: \.isDefault) ?? vehicles.first)?.id
        if let p = prefill {
            if let l = p.liters { litersText = l.clean }
            if let c = p.totalCost { costText = c.clean }
            if let s = p.stationName { stationName = s }
        }
    }

    private func save() {
        guard let v = vehicle else { return }
        Haptics.success()
        let log = FuelLog(
            date: date, vehicleId: v.id, vehicleName: v.name, fuelType: v.fuelType,
            litersPurchased: liters, totalCostPHP: cost, pricePerLiter: pricePerL,
            odometerKm: Double(odometerText.trimmingCharacters(in: .whitespaces)),
            isFullTank: isFullTank,
            stationName: stationName.isEmpty ? nil : stationName,
            notes: notes.isEmpty ? nil : notes)
        context.insert(log)
        try? context.save()
        dismiss()
    }
}
