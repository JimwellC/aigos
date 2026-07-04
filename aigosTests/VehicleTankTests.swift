//
//  VehicleTankTests.swift
//  aigosTests
//
//  Real per-vehicle tank capacities from the database, plus the type-based
//  fallback for models without a listed tank size.
//

import XCTest
@testable import aigos

final class VehicleTankTests: XCTestCase {

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
        XCTAssertEqual(entry?.tankCapacityL, 42)   // car typical tank
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
