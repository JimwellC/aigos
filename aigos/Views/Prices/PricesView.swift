//
//  PricesView.swift
//  aigos
//
//  The fuel-price panel (Tab 4, Section 6 Feature 03). All prices user-editable;
//  the last-updated date is always shown so users can judge staleness. Editing a
//  price marks it "user"-updated — the ultimate safety net against stale data.
//

import SwiftUI
import SwiftData

struct PricesView: View {
    @Environment(\.modelContext) private var context
    @Query private var prices: [FuelPriceCache]

    /// Ordered by the canonical fuel-type sequence (FuelType isn't Comparable, so
    /// we can't sort in the @Query itself).
    private var sortedPrices: [FuelPriceCache] {
        let order = Dictionary(
            uniqueKeysWithValues: FuelType.allCases.enumerated().map { ($1, $0) }
        )
        return prices.sorted { (order[$0.fuelType] ?? 0) < (order[$1.fuelType] ?? 0) }
    }

    private var lastUpdated: Date? {
        prices.map(\.lastUpdated).max()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(sortedPrices) { price in
                        PriceRowView(price: price) { save() }
                    }
                } header: {
                    Text("Price per litre (PHP)")
                } footer: {
                    if let lastUpdated {
                        Text("Last updated \(lastUpdated.formatted(date: .abbreviated, time: .omitted)). Prices are editable — tap any value to change it before calculating.")
                    } else {
                        Text("Prices are editable — tap any value to change it before calculating.")
                    }
                }
            }
            .navigationTitle("Prices")
        }
    }

    private func save() {
        try? context.save()
    }
}

#Preview {
    PricesView()
        .modelContainer(for: [
            VehicleProfile.self, DrivingProfile.self, TripRecord.self,
            SavedRoute.self, FuelPriceCache.self,
        ], inMemory: true)
}
