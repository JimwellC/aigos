//
//  VehicleDeletionTests.swift
//  aigosTests
//
//  Deleting a vehicle removes it + its DrivingProfile (cascade) but PRESERVES
//  the trip history (TripRecord snapshots the vehicle name, not a relationship).
//

import XCTest
import SwiftData
@testable import aigos

final class VehicleDeletionTests: XCTestCase {

    @MainActor
    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            VehicleProfile.self, DrivingProfile.self, TripRecord.self,
            SavedRoute.self, FuelPriceCache.self, PersonalPlace.self,
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    private func sampleTrip(vehicleName: String) -> TripRecord {
        let est = CalculationEngine.estimate(
            distanceKm: 100, baseEfficiencyKmL: 14.5, fuelPricePerLitre: 60,
            avgHighwaySpeedKmh: 90, avgCitySpeedKmh: 40, acInUse: true, roadType: .highway)
        return TripRecord(
            origin: "Manila", destination: "Batangas", vehicleName: vehicleName,
            fuelType: .unleaded91, estimate: est, avgHighwaySpeed: 90, avgCitySpeed: 40,
            roadType: .highway, acWasOn: true)
    }

    @MainActor
    func testDeleteVehiclePreservesTripHistory() throws {
        let ctx = try makeContext()

        let vehicle = VehicleProfile(name: "My Vios", type: .car, fuelType: .unleaded91,
                                     efficiencyKmL: 14.5, isDefault: true)
        let profile = DrivingProfile()
        vehicle.drivingProfile = profile
        ctx.insert(vehicle)
        ctx.insert(profile)
        ctx.insert(sampleTrip(vehicleName: "My Vios"))
        ctx.insert(sampleTrip(vehicleName: "My Vios"))
        try ctx.save()

        // Delete the vehicle.
        ctx.delete(vehicle)
        try ctx.save()

        // Trips survive with their snapshot name intact.
        let trips = try ctx.fetch(FetchDescriptor<TripRecord>())
        XCTAssertEqual(trips.count, 2, "trip history must be preserved")
        XCTAssertTrue(trips.allSatisfy { $0.vehicleName == "My Vios" })

        // The vehicle and its cascade-linked driving profile are gone.
        XCTAssertTrue(try ctx.fetch(FetchDescriptor<VehicleProfile>()).isEmpty)
        XCTAssertTrue(try ctx.fetch(FetchDescriptor<DrivingProfile>()).isEmpty,
                      "DrivingProfile should cascade-delete with its vehicle")
    }

    @MainActor
    func testDeletingDefaultLeavesExactlyOneDefaultCandidate() throws {
        // Mirrors VehiclePicker.delete: after removing the default, the first
        // remaining vehicle is promoted so a default still exists.
        let ctx = try makeContext()
        let a = VehicleProfile(name: "A", type: .car, fuelType: .unleaded91, efficiencyKmL: 14, isDefault: true)
        let b = VehicleProfile(name: "B", type: .car, fuelType: .diesel, efficiencyKmL: 11, isDefault: false)
        ctx.insert(a); ctx.insert(b)
        try ctx.save()

        let remaining = [b]
        ctx.delete(a)
        if !remaining.contains(where: \.isDefault), let first = remaining.first { first.isDefault = true }
        try ctx.save()

        let all = try ctx.fetch(FetchDescriptor<VehicleProfile>())
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.filter(\.isDefault).count, 1, "exactly one default remains")
        XCTAssertEqual(all.first?.name, "B")
    }
}
