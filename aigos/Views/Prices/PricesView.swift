//
//  PricesView.swift
//  aigos
//
//  The fuel-price panel (Tab 4, Feature 03). All prices user-editable; the
//  last-updated date is always shown. Editing a price marks it user-updated — the
//  ultimate safety net against stale data.
//

import SwiftUI
import SwiftData

struct PricesView: View {
    @Environment(\.modelContext) private var context
    @Query private var prices: [FuelPriceCache]

    private var sortedPrices: [FuelPriceCache] {
        let order = Dictionary(uniqueKeysWithValues: FuelType.allCases.enumerated().map { ($1, $0) })
        return prices.sorted { (order[$0.fuelType] ?? 0) < (order[$1.fuelType] ?? 0) }
    }

    private var lastUpdated: Date? { prices.map(\.lastUpdated).max() }

    var body: some View {
        ZStack {
            AigosBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    Text("PRICES").screenTitle()

                    FieldLabel("Price per litre (PHP)")

                    VStack(spacing: 0) {
                        ForEach(Array(sortedPrices.enumerated()), id: \.element.id) { index, price in
                            PriceRowView(price: price) { try? context.save() }
                            if index < sortedPrices.count - 1 {
                                Divider().overlay(Color.white.opacity(0.15))
                            }
                        }
                    }
                    .padding(.vertical, Space.xs)
                    .glassCard()

                    HStack {
                        if let lastUpdated {
                            HStack(spacing: 6) {
                                Image(systemName: "clock.fill").font(.system(size: 11, weight: .semibold))
                                Text("Updated \(lastUpdated.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(Color.white.opacity(0.85))
                            .padding(.horizontal, Space.md)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(Color.white.opacity(0.15)))
                        }
                        Spacer()
                    }

                    Text("Tap a price to edit it before calculating.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                .padding(.horizontal, Space.screen)
                .padding(.top, Space.xl)
                .padding(.bottom, Space.xxl)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
}

#Preview {
    PricesView()
        .modelContainer(for: [
            VehicleProfile.self, DrivingProfile.self, TripRecord.self,
            SavedRoute.self, FuelPriceCache.self,
            PersonalPlace.self,
        ], inMemory: true)
}
