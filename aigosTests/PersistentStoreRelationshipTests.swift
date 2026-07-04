//
//  PersistentStoreRelationshipTests.swift
//  aigosTests
//
//  Regression tests for the build-60 device crash: tapping "Set as Default"
//  called context.save(), and SwiftData faulted with swift_dynamicCastFailure
//  while serializing the VehicleProfile ⇄ DrivingProfile relationship — because
//  that relationship was one-way (no inverse). These tests exercise save/mutate/
//  delete against a PERSISTENT (on-disk) store — the closest thing to the device
//  the simulator offers, and the case the in-memory tests don't cover — with the
//  relationship now bidirectional (VehicleProfile.drivingProfile ⇄
//  DrivingProfile.vehicle).
//

import XCTest
import SwiftData
@testable import aigos

final class PersistentStoreRelationshipTests: XCTestCase {

    @MainActor
    private func makePersistentContext() throws -> ModelContext {
        let schema = Schema([
            VehicleProfile.self, DrivingProfile.self, TripRecord.self,
            SavedRoute.self, FuelPriceCache.self, PersonalPlace.self,
        ])
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("aigos-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let config = ModelConfiguration(schema: schema, url: dir.appendingPathComponent("store.sqlite"))
        return ModelContext(try ModelContainer(for: schema, configurations: [config]))
    }

    @MainActor
    private func vehicleWithProfile(_ name: String, isDefault: Bool = false) -> VehicleProfile {
        let v = VehicleProfile(name: name, type: .car, fuelType: .premium95,
                               efficiencyKmL: 14, isDefault: isDefault,
                               manufacturingYear: 2020, maintenanceStatus: .average)
        v.drivingProfile = DrivingProfile(vehicleId: v.id)   // sets the inverse automatically
        return v
    }

    /// The exact crashing action: mutate isDefault across vehicles that own a
    /// DrivingProfile, then save, on a persistent store. Must not fault.
    @MainActor
    func testSetDefaultAndSaveWithRelationship() throws {
        let ctx = try makePersistentContext()
        let a = vehicleWithProfile("A", isDefault: true)
        let b = vehicleWithProfile("B")
        ctx.insert(a); ctx.insert(b)
        try ctx.save()

        let all = try ctx.fetch(FetchDescriptor<VehicleProfile>())
        for v in all { v.isDefault = (v.id == b.id) }
        try ctx.save()

        let defaults = try ctx.fetch(FetchDescriptor<VehicleProfile>()).filter(\.isDefault)
        XCTAssertEqual(defaults.count, 1)
        XCTAssertEqual(defaults.first?.name, "B")
    }

    /// The inverse is wired both ways.
    @MainActor
    func testInverseIsPopulated() throws {
        let ctx = try makePersistentContext()
        let a = vehicleWithProfile("A")
        ctx.insert(a)
        try ctx.save()

        let profile = try ctx.fetch(FetchDescriptor<DrivingProfile>()).first
        XCTAssertNotNil(profile?.vehicle, "DrivingProfile.vehicle inverse must be set")
        XCTAssertEqual(profile?.vehicle?.name, "A")
    }

    /// Cascade delete still removes the DrivingProfile with its vehicle.
    @MainActor
    func testCascadeDeleteThroughRelationship() throws {
        let ctx = try makePersistentContext()
        let a = vehicleWithProfile("A")
        ctx.insert(a)
        try ctx.save()
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<DrivingProfile>()).count, 1)

        ctx.delete(a)
        try ctx.save()
        XCTAssertTrue(try ctx.fetch(FetchDescriptor<VehicleProfile>()).isEmpty)
        XCTAssertTrue(try ctx.fetch(FetchDescriptor<DrivingProfile>()).isEmpty,
                      "DrivingProfile should cascade-delete with its vehicle")
    }

    /// The Calculate path: saving a TripRecord + updating the learning profile.
    @MainActor
    func testTripSaveAndLearnOnPersistentStore() throws {
        let ctx = try makePersistentContext()
        let a = vehicleWithProfile("A", isDefault: true)
        ctx.insert(a)
        try ctx.save()

        let est = CalculationEngine.estimate(
            distanceKm: 100, baseEfficiencyKmL: 14.5, fuelPricePerLitre: 60,
            avgHighwaySpeedKmh: 90, avgCitySpeedKmh: 40, acInUse: true, roadType: .highway)
        let trip = TripRecord(origin: "Manila", destination: "Batangas", vehicleName: "A",
                              fuelType: .premium95, estimate: est, avgHighwaySpeed: 90,
                              avgCitySpeed: 40, roadType: .highway, acWasOn: true)
        ctx.insert(trip)
        if let p = a.drivingProfile { ProfileLearningEngine.updateProfile(p, with: trip) }
        try ctx.save()

        XCTAssertEqual(try ctx.fetch(FetchDescriptor<TripRecord>()).count, 1)
    }
}
