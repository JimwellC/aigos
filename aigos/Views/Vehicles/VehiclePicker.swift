//
//  VehiclePicker.swift
//  aigos
//
//  Sheet for selecting the active vehicle and managing the garage (Feature 04).
//  Tap a row to select it for calculation; swipe left (or long-press) to Edit,
//  Set as Default, or Delete. The default vehicle shows an amber checkmark; the
//  vehicle currently selected for calculation gets an amber ring around its icon.
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
    @State private var editingVehicle: VehicleProfile?
    @State private var pendingDelete: VehicleProfile?

    var body: some View {
        NavigationStack {
            ZStack {
                AigosBackground()

                if vehicles.isEmpty {
                    MascotEmptyState(
                        title: "No vehicles yet",
                        message: "Add a vehicle to continue calculating trips."
                    )
                } else {
                    garageList
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
            .sheet(item: $editingVehicle) { vehicle in
                AddVehicleView(selectedVehicleID: $selectedVehicleID, editing: vehicle)
            }
            .alert("Delete \(pendingDelete?.name ?? "vehicle")?",
                   isPresented: Binding(get: { pendingDelete != nil },
                                        set: { if !$0 { pendingDelete = nil } }),
                   presenting: pendingDelete) { vehicle in
                Button("Delete", role: .destructive) { delete(vehicle) }
                Button("Cancel", role: .cancel) { }
            } message: { _ in
                Text("This will remove the vehicle and its driving profile. Trip history will be preserved.")
            }
        }
    }

    private var garageList: some View {
        List {
            ForEach(vehicles) { vehicle in
                row(vehicle)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: Space.screen, bottom: 6, trailing: Space.screen))
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            pendingDelete = vehicle
                        } label: { Label("Delete", systemImage: "trash") }
                        Button {
                            editingVehicle = vehicle
                        } label: { Label("Edit", systemImage: "pencil") }
                            .tint(Color.aigosAmber)
                    }
                    .contextMenu {
                        Button { editingVehicle = vehicle } label: { Label("Edit", systemImage: "pencil") }
                        if !vehicle.isDefault {
                            Button { setDefault(vehicle) } label: { Label("Set as Default", systemImage: "checkmark.circle") }
                        }
                        Button(role: .destructive) { pendingDelete = vehicle } label: { Label("Delete", systemImage: "trash") }
                    }
            }

            Text("Swipe left to edit or delete a vehicle")
                .rounded(12)
                .foregroundStyle(Color.white.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .padding(.top, Space.sm)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func row(_ vehicle: VehicleProfile) -> some View {
        let selected = vehicle.id == selectedVehicleID
        return HStack(spacing: Space.md) {
            Image(systemName: vehicle.type.systemImage)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Color.aigosAmber.opacity(0.9), in: Circle())
                // Amber ring = currently selected for calculation (distinct from default).
                .overlay {
                    if selected {
                        Circle().strokeBorder(Color.aigosAmberLight, lineWidth: 3)
                            .frame(width: 50, height: 50)
                    }
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(vehicle.name)
                    .rounded(16, weight: .semibold)
                    .foregroundStyle(.white)
                Text("\(vehicle.fuelType.label) · \(fuelUnit.format(kmL: vehicle.efficiencyKmL)) · \(vehicle.tankCapacityL.clean)L tank")
                    .rounded(13)
                    .foregroundStyle(Color.aigosTextSecondary)
            }
            Spacer()
            // Amber checkmark = the default vehicle.
            if vehicle.isDefault {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.aigosAmber)
                    .font(.system(size: 20))
            }
        }
        .padding(Space.md)
        .glassCard()
        .contentShape(Rectangle())
        .onTapGesture {
            selectedVehicleID = vehicle.id
            dismiss()
        }
    }

    // MARK: - Actions

    private func setDefault(_ vehicle: VehicleProfile) {
        Haptics.tap(.light)   // vehicle set as default
        VehicleProfile.setAsDefault(vehicle, context: context)
    }

    private func delete(_ vehicle: VehicleProfile) {
        let wasSelected = vehicle.id == selectedVehicleID
        let wasDefault = vehicle.isDefault
        let remaining = vehicles.filter { $0.id != vehicle.id }

        context.delete(vehicle)   // cascade-deletes the linked DrivingProfile
        // If the selected-for-calc vehicle was deleted, fall back to the first left.
        if wasSelected { selectedVehicleID = remaining.first?.id }

        // If the default was deleted, promote the first remaining vehicle. This
        // fetch-clears-sets-saves once (and covers the post-delete save too).
        if wasDefault, let first = remaining.first {
            VehicleProfile.setAsDefault(first, context: context)
        } else {
            do { try context.save() } catch {
                #if DEBUG
                print("⚠️ delete vehicle save failed: \(error)")
                #endif
            }
        }
    }
}
