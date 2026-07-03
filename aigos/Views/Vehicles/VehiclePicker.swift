//
//  VehiclePicker.swift
//  aigos
//
//  Sheet for selecting the active vehicle and managing the garage (Feature 04).
//

import SwiftUI
import SwiftData

struct VehiclePicker: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \VehicleProfile.createdAt) private var vehicles: [VehicleProfile]
    @AppStorage("fuelUnit") private var fuelUnit: FuelUnit = .kmPerL

    @Binding var selectedVehicleID: UUID?
    @State private var showingAddVehicle = false

    var body: some View {
        NavigationStack {
            ZStack {
                AigosBackground()

                ScrollView {
                    VStack(spacing: Space.md) {
                        ForEach(vehicles) { vehicle in
                            Button {
                                Haptics.tap(.light)
                                selectedVehicleID = vehicle.id
                                dismiss()
                            } label: {
                                HStack(spacing: Space.md) {
                                    Image(systemName: vehicle.type.systemImage)
                                        .foregroundStyle(.white)
                                        .frame(width: 40, height: 40)
                                        .background(Color.aigosAmber.opacity(0.9), in: Circle())
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(vehicle.name)
                                            .rounded(16, weight: .semibold)
                                            .foregroundStyle(.white)
                                        Text("\(vehicle.fuelType.label) · \(fuelUnit.format(kmL: vehicle.efficiencyKmL))")
                                            .rounded(13)
                                            .foregroundStyle(Color.aigosTextSecondary)
                                    }
                                    Spacer()
                                    if vehicle.id == selectedVehicleID {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.white)
                                    }
                                }
                                .padding(Space.md)
                                .glassCard()
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) { delete(vehicle) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }

                        if vehicles.isEmpty {
                            MascotEmptyState(
                                title: "No vehicles yet",
                                message: "Add your vehicle to get started."
                            )
                            .padding(.top, Space.xl)
                        }
                    }
                    .padding(.horizontal, Space.screen)
                    .padding(.vertical, Space.lg)
                }
            }
            .navigationTitle("Vehicles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.aigosAmberDeep, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }.tint(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAddVehicle = true } label: { Image(systemName: "plus") }
                        .tint(.white)
                }
            }
            .sheet(isPresented: $showingAddVehicle) {
                AddVehicleView(selectedVehicleID: $selectedVehicleID)
            }
        }
    }

    private func delete(_ vehicle: VehicleProfile) {
        if vehicle.id == selectedVehicleID { selectedVehicleID = nil }
        context.delete(vehicle)
        try? context.save()
    }
}
