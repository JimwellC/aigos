//
//  FuelPriceCache.swift
//  aigos
//
//  One row per fuel type. Seeded on first launch from the bundled FuelPrices.json
//  and editable by the user in the Prices tab. The last-updated date is always
//  shown so users can judge staleness (Section 9 / 15).
//

import Foundation
import SwiftData

@Model
final class FuelPriceCache {
    var id: UUID = UUID()
    var fuelType: FuelType = FuelType.ron95
    var pricePHP: Double = 0            // e.g. 62.55
    var lastUpdated: Date = Date()
    var updatedBy: String = "developer" // "developer" | "user"

    init(
        fuelType: FuelType,
        pricePHP: Double,
        lastUpdated: Date,
        updatedBy: String = "developer"
    ) {
        self.id = UUID()
        self.fuelType = fuelType
        self.pricePHP = pricePHP
        self.lastUpdated = lastUpdated
        self.updatedBy = updatedBy
    }
}
