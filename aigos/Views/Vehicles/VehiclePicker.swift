//
//  VehiclePicker.swift
//  aigos
//
//  Sheet for selecting the active vehicle and adding new ones (Section 6, Feature
//  04). Full add/edit/delete management lives here in Sprint 1.
//

import SwiftUI
import SwiftData

struct VehiclePicker: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \VehicleProfile.createdAt) private var vehicles: [VehicleProfile]

    @Binding var selectedVehicleID: UUID?
    @State private var showingAddVehicle = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(vehicles) { vehicle in
                    Button {
                        selectedVehicleID = vehicle.id
                        dismiss()
                    } label: {
                        HStack {
                            Label(vehicle.name, systemImage: vehicle.type.systemImage)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("\(vehicle.fuelType.label) · \(vehicle.efficiencyKmL.oneDecimal) km/L")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if vehicle.id == selectedVehicleID {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.aigosAmber)
                            }
                        }
                    }
                }
                .onDelete(perform: delete)
            }
            .navigationTitle("Vehicles")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddVehicle = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddVehicle) {
                AddVehicleView(selectedVehicleID: $selectedVehicleID)
            }
            .overlay {
                if vehicles.isEmpty {
                    ContentUnavailableView(
                        "No vehicles yet",
                        systemImage: "car",
                        description: Text("Add your first vehicle to start calculating.")
                    )
                }
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let vehicle = vehicles[index]
            if vehicle.id == selectedVehicleID { selectedVehicleID = nil }
            context.delete(vehicle)
        }
        try? context.save()
    }
}
