//
//  AppSeeder.swift
//  aigos
//
//  First-launch seeding: loads fuel prices from the bundled FuelPrices.json and
//  creates one sample vehicle so the calculator works immediately. Onboarding
//  (Sprint 2) will take over vehicle creation.
//

import Foundation
import SwiftData

@MainActor
enum AppSeeder {

    /// Bundled price file shape (Resources/FuelPrices.json).
    private struct PriceFile: Decodable {
        let lastUpdated: String            // ISO "yyyy-MM-dd"
        let prices: [String: Double]       // keyed by FuelType.rawValue
    }

    static func seedIfNeeded(_ context: ModelContext) {
        seedPricesIfNeeded(context)
        seedSampleVehicleIfNeeded(context)
    }

    // MARK: - Prices

    private static func seedPricesIfNeeded(_ context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<FuelPriceCache>())) ?? []
        guard existing.isEmpty else { return }

        let file = loadPriceFile()
        let updatedAt = file.flatMap { parseDate($0.lastUpdated) } ?? Date()

        for type in FuelType.allCases {
            let price = file?.prices[type.rawValue] ?? type.seedPrice
            context.insert(FuelPriceCache(
                fuelType: type,
                pricePHP: price,
                lastUpdated: updatedAt,
                updatedBy: "developer"
            ))
        }
        try? context.save()
    }

    private static func loadPriceFile() -> PriceFile? {
        guard let url = Bundle.main.url(forResource: "FuelPrices", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(PriceFile.self, from: data)
    }

    private static func parseDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }

    // MARK: - Sample vehicle

    private static func seedSampleVehicleIfNeeded(_ context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<VehicleProfile>())) ?? []
        guard existing.isEmpty else { return }

        let vehicle = VehicleProfile(
            name: "My Car",
            type: .car,
            fuelType: .ron95,
            efficiencyKmL: 12.0,
            isDefault: true
        )
        let profile = DrivingProfile(vehicleId: vehicle.id)
        vehicle.drivingProfile = profile

        context.insert(vehicle)
        context.insert(profile)
        try? context.save()
    }
}
