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
}
