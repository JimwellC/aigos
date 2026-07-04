//
//  VehicleTankTests.swift
//  aigosTests
//
//  Real per-vehicle tank capacities from the database, plus the type-based
//  fallback for models without a listed tank size.
//

import XCTest
import SwiftData
@testable import aigos

final class VehicleTankTests: XCTestCase {

    @MainActor
    func testLegacyFlat45NormalizedByType() throws {
        let schema = Schema([
            VehicleProfile.self, DrivingProfile.self, TripRecord.self,
            SavedRoute.self, FuelPriceCache.self, PersonalPlace.self,
        ])
        let ctx = ModelContext(try ModelContainer(
            for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        // Simulate pre-tank-field vehicles migrated to the flat 45 L default.
        let moto = VehicleProfile(name: "My motor", type: .motorcycle, fuelType: .unleaded91,
                                  efficiencyKmL: 45, tankCapacityL: 45)
        let van = VehicleProfile(name: "Van", type: .van, fuelType: .diesel,
                                 efficiencyKmL: 10, tankCapacityL: 45)
        let car = VehicleProfile(name: "Car", type: .car, fuelType: .premium95,
                                 efficiencyKmL: 14, tankCapacityL: 45)
        ctx.insert(moto); ctx.insert(van); ctx.insert(car)
        try ctx.save()

        UserDefaults.standard.removeObject(forKey: "tankCapacityNormalized_v1")
        AppSeeder.normalizeTankCapacitiesIfNeeded(ctx)

        XCTAssertEqual(moto.tankCapacityL, 5, "motorcycle at flat 45 → type default 5")
        XCTAssertEqual(van.tankCapacityL, 65, "van at flat 45 → type default 65")
        XCTAssertEqual(car.tankCapacityL, 45, "car at 45 is correct — unchanged")
        UserDefaults.standard.removeObject(forKey: "tankCapacityNormalized_v1")
    }


    func testKnownCarHasRealTank() {
        XCTAssertEqual(VehicleDatabase.find("Vios")?.tankCapacityL, 42)
        XCTAssertEqual(VehicleDatabase.find("Fortuner")?.tankCapacityL, 65)
        XCTAssertEqual(VehicleDatabase.find("Land Cruiser")?.tankCapacityL, 87)
    }

    func testMotorcycleHasRealTank() {
        XCTAssertEqual(VehicleDatabase.find("Beat")?.tankCapacityL, 3.7)
        // Use "PCX" (unambiguous); "NMAX" contains "max" and also matches D-Max.
        XCTAssertEqual(VehicleDatabase.find("PCX")?.tankCapacityL, 8.1)
    }

    func testUnknownCarFallsBackToTypeTypical() {
        // A car with no listed tank → type fallback (car = 45 L).
        let entry = VehicleDatabase.entries.first { $0.vehicleType == .car && $0.tankL == nil }
        XCTAssertNotNil(entry, "expected at least one car without a listed tank")
        XCTAssertEqual(entry?.tankCapacityL, VehicleType.car.typicalTankLiters)
        XCTAssertEqual(entry?.tankCapacityL, 45)   // car fallback tank
    }

    func testAnswerCarriesTankCapacity() {
        // "Use this efficiency" should hand the tank size into the vehicle draft.
        let a = VehicleDatabase.answer(for: "what's the km/L of a Vios?")
        XCTAssertEqual(a?.efficiencyKmL, 14.7)
        XCTAssertEqual(a?.tankCapacityL, 42)
    }

    func testVehicleProfileDefaultTank() {
        let v = VehicleProfile(name: "X", type: .car, fuelType: .unleaded91, efficiencyKmL: 14)
        XCTAssertEqual(v.tankCapacityL, 45, "unknown-vehicle default tank is 45 L")
    }
}
