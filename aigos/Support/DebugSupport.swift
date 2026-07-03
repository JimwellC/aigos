//
//  DebugSupport.swift
//  aigos
//
//  DEBUG-only launch affordances for driving the app headlessly (screenshots,
//  manual QA). Never compiled into release builds.
//
//    -seedDemo        Wipe + seed a vehicle, trips across two months, a saved
//                     route, and mark onboarding complete.
//    -tab <name>      Open directly on a tab: calculate|history|saved|prices|settings
//    (with -seedDemo, Calculate auto-runs a sample estimate on appear.)
//

#if DEBUG
import Foundation
import SwiftData

enum DebugSupport {
    static var isSeedDemo: Bool {
        ProcessInfo.processInfo.arguments.contains("-seedDemo")
    }

    /// Auto-present Talk to aigos (optionally with a seeded query) for screenshots.
    static var autoOpenTalk: Bool {
        ProcessInfo.processInfo.arguments.contains("-talk")
    }

    static var talkQuery: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-talkQuery"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    /// A follow-up message sent after -talkQuery, to exercise conversational context.
    static var talkQuery2: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-talkQuery2"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    static var initialTab: Tab? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-tab"), i + 1 < args.count else { return nil }
        switch args[i + 1] {
        case "calculate": return .calculate
        case "history": return .history
        case "saved": return .saved
        case "prices": return .prices
        case "settings": return .settings
        default: return nil
        }
    }

    /// A prefilled draft so the Calculate screen shows a populated result.
    static var demoDraft: CalculatorDraft {
        CalculatorDraft(origin: "Manila", destination: "Batangas", distanceKm: 99.2,
                        vehicleId: nil, traffic: .heavy, acOn: true, load: .moderate)
    }

    /// Force a low fuel level so the refuel warning shows in screenshots.
    static var lowFuel: Bool {
        ProcessInfo.processInfo.arguments.contains("-lowFuel")
    }

    @MainActor
    static func seed(_ context: ModelContext) {
        // Wipe everything for a deterministic demo state.
        try? context.delete(model: TripRecord.self)
        try? context.delete(model: SavedRoute.self)
        try? context.delete(model: VehicleProfile.self)
        try? context.delete(model: DrivingProfile.self)
        try? context.delete(model: FuelPriceCache.self)
        try? context.delete(model: PersonalPlace.self)
        try? context.save()

        AppSeeder.seedPricesIfNeeded(context)

        let vehicle = VehicleProfile(
            name: "My Vios", type: .car, fuelType: .ron95, efficiencyKmL: 14.5, isDefault: true
        )
        let profile = DrivingProfile(vehicleId: vehicle.id)
        profile.avgHighwaySpeedKmh = 110
        profile.avgCitySpeedKmh = 40
        profile.tripCount = 8
        profile.avgActualHighwaySpeed = 108
        profile.avgActualCitySpeed = 38
        profile.confidenceLevel = .building
        vehicle.drivingProfile = profile
        context.insert(vehicle)
        context.insert(profile)

        let cal = Calendar.current
        let now = Date()
        let lastMonth = cal.date(byAdding: .month, value: -1, to: now) ?? now
        let samples: [(String, String, Double, Double, Date)] = [
            ("Manila", "Batangas", 99.2, 512.40, now),
            ("Home", "Office", 24.5, 128.90, now),
            ("Makati", "Tagaytay", 58.0, 305.10, now),
            ("Manila", "Baguio", 246.0, 1290.55, lastMonth),
            ("Home", "Office", 24.5, 131.20, lastMonth),
        ]
        for (o, d, km, cost, when) in samples {
            let est = CalculationEngine.estimate(
                distanceKm: km, baseEfficiencyKmL: 14.5, fuelPricePerLitre: 62.55,
                avgHighwaySpeedKmh: 110, avgCitySpeedKmh: 40, acInUse: true, roadType: .highway
            )
            let trip = TripRecord(
                origin: o, destination: d, vehicleName: vehicle.name, fuelType: .ron95,
                estimate: est, avgHighwaySpeed: 110, avgCitySpeed: 40, roadType: .highway, acWasOn: true
            )
            trip.totalCostPHP = cost
            trip.calculatedAt = when
            context.insert(trip)
        }

        context.insert(SavedRoute(
            name: "Home → Office", origin: "Home", destination: "Office",
            distanceKm: 24.5, defaultVehicleId: vehicle.id
        ))

        context.insert(PersonalPlace(name: "Home", gazetteerKey: "makati"))
        context.insert(PersonalPlace(name: "Office", gazetteerKey: "pasig"))
        context.insert(PersonalPlace(name: "School", gazetteerKey: ""))

        try? context.save()
        UserDefaults.standard.set(true, forKey: "hasOnboarded")
    }
}
#endif
