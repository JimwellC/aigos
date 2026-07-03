//
//  SettingsView.swift
//  aigos
//
//  Settings (Tab 5, Feature 08): fuel-unit toggle, default vehicle, reset driving
//  profile, clear history, and the disclaimer. Glass sections over the gradient.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \VehicleProfile.createdAt) private var vehicles: [VehicleProfile]
    @AppStorage("fuelUnit") private var fuelUnit: FuelUnit = .kmPerL

    @State private var showingClearConfirm = false
    @State private var showingResetConfirm = false

    var body: some View {
        ZStack {
            AigosBackground(deep: true)

            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    Text("SETTINGS")
                        .rounded(30, weight: .bold)
                        .kerning(1.5)
                        .foregroundStyle(.white)

                    unitsSection
                    if !vehicles.isEmpty { defaultVehicleSection }
                    dataSection
                    disclaimerSection

                    Text("aigos 1.0 — offline, privacy-first. No account, no cloud, no tracking.")
                        .rounded(12)
                        .foregroundStyle(Color.aigosTextTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.horizontal, Space.screen)
                .padding(.top, Space.xl)
                .padding(.bottom, Space.xxl)
            }
        }
        .confirmationDialog("Clear all trip history?", isPresented: $showingClearConfirm, titleVisibility: .visible) {
            Button("Clear history", role: .destructive, action: clearHistory)
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Reset the default vehicle's learned driving profile?", isPresented: $showingResetConfirm, titleVisibility: .visible) {
            Button("Reset profile", role: .destructive, action: resetProfile)
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Sections

    private var unitsSection: some View {
        section("Units") {
            HStack {
                Text("Fuel efficiency")
                    .rounded(16, weight: .medium)
                    .foregroundStyle(.white)
                Spacer()
                HStack(spacing: Space.xs) {
                    ForEach(FuelUnit.allCases) { unit in
                        let selected = fuelUnit == unit
                        Text(unit.label)
                            .rounded(13, weight: .semibold)
                            .foregroundStyle(selected ? .white : Color.aigosTextSecondary)
                            .padding(.horizontal, Space.md)
                            .padding(.vertical, 8)
                            .background(selected ? Color.aigosAmber : Color.white.opacity(0.12), in: Capsule())
                            .onTapGesture { Haptics.tap(.light); fuelUnit = unit }
                    }
                }
            }
        }
    }

    private var defaultVehicleSection: some View {
        section("Default vehicle") {
            VStack(spacing: Space.sm) {
                ForEach(vehicles) { vehicle in
                    Button {
                        Haptics.tap(.light)
                        setDefault(vehicle)
                    } label: {
                        HStack {
                            Image(systemName: vehicle.type.systemImage)
                                .foregroundStyle(Color.aigosAmber)
                            Text(vehicle.name)
                                .rounded(16, weight: .medium)
                                .foregroundStyle(.white)
                            Spacer()
                            if vehicle.isDefault {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.aigosAmber)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var dataSection: some View {
        section("Data") {
            VStack(spacing: Space.md) {
                Button {
                    showingResetConfirm = true
                } label: {
                    rowLabel("Reset driving profile", systemImage: "brain.head.profile", tint: .white)
                }
                .disabled(vehicles.isEmpty)
                Divider().overlay(Color.white.opacity(0.15))
                Button {
                    showingClearConfirm = true
                } label: {
                    rowLabel("Clear trip history", systemImage: "trash", tint: Color(hex: "#FFB4A2"))
                }
            }
        }
    }

    private var disclaimerSection: some View {
        section("Disclaimer") {
            Text("aigos gives estimates only. Actual fuel use varies with traffic, load, tyre pressure, and driving style. Prices are user-editable and may not reflect the latest pump rates. Always confirm before relying on an estimate.")
                .rounded(13)
                .foregroundStyle(Color.aigosTextSecondary)
        }
    }

    // MARK: - Helpers

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            FieldLabel(title)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Space.md)
                .glassCard()
        }
    }

    private func rowLabel(_ title: String, systemImage: String, tint: Color) -> some View {
        HStack {
            Image(systemName: systemImage)
            Text(title).rounded(16, weight: .medium)
            Spacer()
        }
        .foregroundStyle(tint)
    }

    // MARK: - Actions

    private func setDefault(_ vehicle: VehicleProfile) {
        for v in vehicles { v.isDefault = (v.id == vehicle.id) }
        try? context.save()
    }

    private func resetProfile() {
        guard let profile = (vehicles.first(where: \.isDefault) ?? vehicles.first)?.drivingProfile else { return }
        profile.tripCount = 0
        profile.avgActualHighwaySpeed = nil
        profile.avgActualCitySpeed = nil
        profile.acUsageRate = profile.usesACByDefault ? 1.0 : 0.0
        profile.confidenceLevel = .new
        profile.lastUpdated = Date()
        try? context.save()
    }

    private func clearHistory() {
        try? context.delete(model: TripRecord.self)
        try? context.save()
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [
            VehicleProfile.self, DrivingProfile.self, TripRecord.self,
            SavedRoute.self, FuelPriceCache.self,
        ], inMemory: true)
}
