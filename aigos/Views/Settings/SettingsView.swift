//
//  SettingsView.swift
//  aigos
//
//  Settings (Tab 5, Feature 08). Sprint 1 covers the fuel-unit toggle, clear
//  history, and the disclaimer text. Default-vehicle and reset-profile controls
//  arrive with onboarding in Sprint 2.
//

import SwiftUI
import SwiftData

/// Fuel efficiency display unit (Section 6).
enum FuelUnit: String, CaseIterable, Identifiable {
    case kmPerL
    case lPer100km

    var id: String { rawValue }
    var label: String {
        switch self {
        case .kmPerL: "km/L"
        case .lPer100km: "L/100km"
        }
    }
}

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("fuelUnit") private var fuelUnit: FuelUnit = .kmPerL
    @State private var showingClearConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Units") {
                    Picker("Fuel efficiency", selection: $fuelUnit) {
                        ForEach(FuelUnit.allCases) { Text($0.label).tag($0) }
                    }
                }

                Section("Data") {
                    Button("Clear trip history", role: .destructive) {
                        showingClearConfirm = true
                    }
                }

                Section("Disclaimer") {
                    Text("aigos gives estimates only. Actual fuel use varies with traffic, load, tyre pressure, and driving style. Prices are user-editable and may not reflect the latest pump rates. Always confirm before relying on an estimate.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    LabeledContent("Version", value: "1.0")
                } footer: {
                    Text("aigos — offline, privacy-first. No account, no cloud, no tracking.")
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                "Clear all trip history?",
                isPresented: $showingClearConfirm,
                titleVisibility: .visible
            ) {
                Button("Clear history", role: .destructive, action: clearHistory)
                Button("Cancel", role: .cancel) {}
            }
        }
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
