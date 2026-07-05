//
//  PriceService.swift
//  aigos
//
//  Read/write helpers for the fuel-price cache (Section 9 / 15). Prices are
//  seeded from the bundled FuelPrices.json and always user-editable.
//

import Foundation
import SwiftData

@MainActor
enum PriceService {

    /// Current price for a fuel type, or its seed price if not yet cached.
    static func price(for fuelType: FuelType, in context: ModelContext) -> Double {
        cache(for: fuelType, in: context)?.pricePHP ?? fuelType.seedPrice
    }

    /// The cache row for a fuel type, if present.
    static func cache(for fuelType: FuelType, in context: ModelContext) -> FuelPriceCache? {
        let all = (try? context.fetch(FetchDescriptor<FuelPriceCache>())) ?? []
        return all.first { $0.fuelType == fuelType }
    }

    /// The most recent update across all cached prices.
    static func latestUpdate(in context: ModelContext) -> Date? {
        let all = (try? context.fetch(FetchDescriptor<FuelPriceCache>())) ?? []
        return all.map(\.lastUpdated).max()
    }

    /// Set a fuel price and mark it user-edited (mirrors the Prices-tab pencil edit:
    /// `updatedBy = "user"`, `lastUpdated = now`). Creates the row if missing.
    /// Returns whether it saved.
    @discardableResult
    static func update(_ fuelType: FuelType, to price: Double, in context: ModelContext) -> Bool {
        if let row = cache(for: fuelType, in: context) {
            row.pricePHP = price
            row.updatedBy = "user"
            row.lastUpdated = Date()
        } else {
            context.insert(FuelPriceCache(fuelType: fuelType, pricePHP: price,
                                          lastUpdated: Date(), updatedBy: "user"))
        }
        do { try context.save(); return true }
        catch {
            #if DEBUG
            print("⚠️ PriceService.update failed: \(error)")
            #endif
            return false
        }
    }
}
