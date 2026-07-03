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
    @Query(sort: \PersonalPlace.createdAt) private var personalPlaces: [PersonalPlace]
    @AppStorage("fuelUnit") private var fuelUnit: FuelUnit = .kmPerL

    @State private var showingClearConfirm = false
    @State private var showingResetConfirm = false
    @State private var editingPlace: PersonalPlace?

    var body: some View {
        ZStack {
            AigosBackground(variant: 4)

            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    Text("SETTINGS").screenTitle()

                    unitsSection
                    if !vehicles.isEmpty { defaultVehicleSection }
                    myPlacesSection
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
        .sheet(item: $editingPlace) { place in
            PersonalPlaceEditor(place: place)
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
                            .rounded(13, weight: selected ? .bold : .semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, Space.md)
                            .padding(.vertical, 8)
                            .pillStyle(selected: selected)
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
                        HStack(spacing: Space.md) {
                            SettingsIcon(systemName: vehicle.type.systemImage)
                            Text(vehicle.name)
                                .rounded(16, weight: .medium)
                                .foregroundStyle(.white)
                            Spacer()
                            if vehicle.isDefault {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var myPlacesSection: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack {
                FieldLabel("My places")
                Spacer()
                Button {
                    Haptics.tap(.light)
                    addPlace()
                } label: {
                    Label("Add", systemImage: "plus")
                        .rounded(13, weight: .semibold)
                        .foregroundStyle(.white.opacity(0.9))
                }
            }

            VStack(spacing: Space.sm) {
                ForEach(Array(personalPlaces.enumerated()), id: \.element.id) { i, place in
                    Button {
                        Haptics.tap(.light)
                        editingPlace = place
                    } label: {
                        HStack(spacing: Space.md) {
                            SettingsIcon(systemName: "mappin")
                            VStack(alignment: .leading, spacing: 2) {
                                Text(place.name.isEmpty ? "Unnamed" : place.name)
                                    .rounded(16, weight: .semibold)
                                    .foregroundStyle(.white)
                                Text(place.isConfigured ? place.gazetteerKey.capitalized : "Tap to set a location")
                                    .rounded(13)
                                    .foregroundStyle(place.isConfigured ? Color.white.opacity(0.75) : Color.white.opacity(0.55))
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(Color.white.opacity(0.4))
                        }
                    }
                    .buttonStyle(.plain)
                    .staggeredAppear(index: i)
                    .contextMenu {
                        Button(role: .destructive) { delete(place) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.md)
        .glassCard()
    }

    private var dataSection: some View {
        section("Data") {
            VStack(spacing: Space.sm) {
                Button {
                    showingResetConfirm = true
                } label: {
                    dataRow("Reset driving profile", systemImage: "brain.head.profile", destructive: false)
                }
                .disabled(vehicles.isEmpty)
                Divider().overlay(Color.white.opacity(0.15))
                Button {
                    showingClearConfirm = true
                } label: {
                    dataRow("Clear trip history", systemImage: "trash", destructive: true)
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

    /// A Data-section row: white text + Settings icon tile. Destructive rows use a
    /// red tile and a subtle red row-background tint (white stays readable on amber).
    private func dataRow(_ title: String, systemImage: String, destructive: Bool) -> some View {
        HStack(spacing: Space.md) {
            SettingsIcon(systemName: systemImage, tile: destructive ? Color(hex: "#A83A2A") : Color(hex: "#8B4A1A"))
            Text(title).rounded(16, weight: .medium).foregroundStyle(.white)
            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, Space.sm)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(destructive ? Color(hex: "#C0392B").opacity(0.28) : Color.clear)
        )
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

    private func addPlace() {
        let place = PersonalPlace(name: "New place")
        context.insert(place)
        try? context.save()
        editingPlace = place
    }

    private func delete(_ place: PersonalPlace) {
        context.delete(place)
        try? context.save()
    }
}

/// Editor sheet: rename a personal place and map it to a gazetteer location.
struct PersonalPlaceEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var place: PersonalPlace

    @State private var search = ""

    private var keys: [String] {
        let all = GazetteerRouteResolver.places.keys.sorted()
        let q = search.lowercased().trimmingCharacters(in: .whitespaces)
        return q.isEmpty ? all : all.filter { $0.contains(q) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AigosBackground(variant: 1)

                ScrollView {
                    VStack(alignment: .leading, spacing: Space.md) {
                        FieldLabel("Shortcut name")
                        GlassField(placeholder: "Home", text: $place.name, autocap: .words)

                        HStack {
                            FieldLabel("Mapped to")
                            Spacer()
                            if place.isConfigured {
                                Button("Clear") {
                                    place.gazetteerKey = ""
                                    save()
                                }
                                .rounded(13, weight: .semibold)
                                .foregroundStyle(.white.opacity(0.9))
                            }
                        }
                        Text(place.isConfigured ? place.gazetteerKey.capitalized : "Not set")
                            .rounded(17, weight: .semibold)
                            .foregroundStyle(place.isConfigured ? .white : Color.white.opacity(0.55))

                        GlassField(placeholder: "Search city or province…", text: $search)

                        LazyVStack(spacing: 0) {
                            ForEach(keys, id: \.self) { key in
                                Button {
                                    Haptics.tap(.light)
                                    place.gazetteerKey = key
                                    save()
                                    dismiss()
                                } label: {
                                    HStack {
                                        Text(key.capitalized)
                                            .rounded(16, weight: .medium)
                                            .foregroundStyle(.white)
                                        Spacer()
                                        if place.gazetteerKey == key {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .padding(.horizontal, Space.md)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)
                                Divider().overlay(Color.white.opacity(0.12))
                            }
                        }
                        .glassCard()
                    }
                    .padding(.horizontal, Space.screen)
                    .padding(.vertical, Space.lg)
                }
            }
            .navigationTitle("Edit Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.aigosAmberDeep, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { save(); dismiss() }.tint(.white)
                }
            }
        }
    }

    private func save() { try? context.save() }
}

#Preview {
    SettingsView()
        .modelContainer(for: [
            VehicleProfile.self, DrivingProfile.self, TripRecord.self,
            SavedRoute.self, FuelPriceCache.self,
            PersonalPlace.self,
        ], inMemory: true)
}
