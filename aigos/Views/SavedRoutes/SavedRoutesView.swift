//
//  SavedRoutesView.swift
//  aigos
//
//  Starred routes for one-tap recalculation (Tab 3, Feature 05). Placeholder for
//  Sprint 1 — starring from History and one-tap recalculate are wired in Sprint 2.
//

import SwiftUI
import SwiftData

struct SavedRoutesView: View {
    @Query(sort: \SavedRoute.savedAt, order: .reverse) private var routes: [SavedRoute]

    var body: some View {
        NavigationStack {
            List {
                ForEach(routes) { route in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(route.name).font(.headline)
                        Text("\(route.origin) → \(route.destination) · \(route.distanceKm.oneDecimal) km")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Saved")
            .overlay {
                if routes.isEmpty {
                    ContentUnavailableView(
                        "No saved routes",
                        systemImage: "star",
                        description: Text("Star a trip from History to save it for one-tap recalculation. Coming in Sprint 2.")
                    )
                }
            }
        }
    }
}

#Preview {
    SavedRoutesView()
        .modelContainer(for: [
            VehicleProfile.self, DrivingProfile.self, TripRecord.self,
            SavedRoute.self, FuelPriceCache.self,
        ], inMemory: true)
}
