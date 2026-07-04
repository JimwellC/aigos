//
//  VehicleDefaultTests.swift
//  aigosTests
//
//  Regression tests for VehicleProfile.setAsDefault — the single safe path used
//  by the garage, Settings, and Add/Edit to change the default vehicle. Covers
//  the P0 "crash when setting default" hardening: fetch-from-context, clear all,
//  set one, save once, catch errors. The invariant checked everywhere is that
//  EXACTLY ONE vehicle is default afterwards.
//

import XCTest
import SwiftData
@testable import aigos

final class VehicleDefaultTests: XCTestCase {

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

    @MainActor
    private func makeVehicle(_ name: String, isDefault: Bool = false) -> VehicleProfile {
        VehicleProfile(name: name, type: .car, fuelType: .unleaded91,
                       efficiencyKmL: 14, isDefault: isDefault)
    }

    private func defaults(_ ctx: ModelContext) throws -> [VehicleProfile] {
        try ctx.fetch(FetchDescriptor<VehicleProfile>()).filter(\.isDefault)
    }

    // (a) Setting the first vehicle as default.
    @MainActor
    func testSetFirstVehicleAsDefault() throws {
        let ctx = try makeContext()
        let a = makeVehicle("A")           // starts non-default
        ctx.insert(a)
        try ctx.save()

        VehicleProfile.setAsDefault(a, context: ctx)

        let ds = try defaults(ctx)
        XCTAssertEqual(ds.count, 1, "exactly one default after setting the first vehicle")
        XCTAssertEqual(ds.first?.name, "A")
    }

    // (b) Switching the default from one vehicle to another — no two defaults.
    @MainActor
    func testSwitchDefaultLeavesExactlyOne() throws {
        let ctx = try makeContext()
        let a = makeVehicle("A", isDefault: true)
        let b = makeVehicle("B")
        let c = makeVehicle("C")
        ctx.insert(a); ctx.insert(b); ctx.insert(c)
        try ctx.save()

        VehicleProfile.setAsDefault(b, context: ctx)

        let ds = try defaults(ctx)
        XCTAssertEqual(ds.count, 1, "switching must not leave two defaults")
        XCTAssertEqual(ds.first?.name, "B")
        XCTAssertFalse(a.isDefault, "old default cleared")
        XCTAssertFalse(c.isDefault, "untouched vehicle stays non-default")
    }

    // Setting the same already-default vehicle is idempotent.
    @MainActor
    func testSetSameDefaultIsIdempotent() throws {
        let ctx = try makeContext()
        let a = makeVehicle("A", isDefault: true)
        let b = makeVehicle("B")
        ctx.insert(a); ctx.insert(b)
        try ctx.save()

        VehicleProfile.setAsDefault(a, context: ctx)

        let ds = try defaults(ctx)
        XCTAssertEqual(ds.count, 1)
        XCTAssertEqual(ds.first?.name, "A")
    }

    // Repairs a corrupt state where two vehicles are somehow both default.
    @MainActor
    func testSetDefaultRepairsMultipleDefaults() throws {
        let ctx = try makeContext()
        let a = makeVehicle("A", isDefault: true)
        let b = makeVehicle("B", isDefault: true)   // corrupt: two defaults
        ctx.insert(a); ctx.insert(b)
        try ctx.save()

        VehicleProfile.setAsDefault(b, context: ctx)

        let ds = try defaults(ctx)
        XCTAssertEqual(ds.count, 1, "double-default state is repaired to exactly one")
        XCTAssertEqual(ds.first?.name, "B")
    }

    // Setting a just-inserted (not-yet-persisted-as-default) vehicle works.
    @MainActor
    func testSetDefaultOnFreshlyInsertedVehicle() throws {
        let ctx = try makeContext()
        let a = makeVehicle("A", isDefault: true)
        ctx.insert(a)
        try ctx.save()

        let b = makeVehicle("B")   // inserted then immediately made default
        ctx.insert(b)
        VehicleProfile.setAsDefault(b, context: ctx)

        let ds = try defaults(ctx)
        XCTAssertEqual(ds.count, 1)
        XCTAssertEqual(ds.first?.name, "B")
    }

    // Deleting the default and promoting the next via the helper keeps one default.
    @MainActor
    func testDeleteDefaultThenPromoteViaHelper() throws {
        let ctx = try makeContext()
        let a = makeVehicle("A", isDefault: true)
        let b = makeVehicle("B")
        ctx.insert(a); ctx.insert(b)
        try ctx.save()

        ctx.delete(a)
        VehicleProfile.setAsDefault(b, context: ctx)   // promote remaining

        let all = try ctx.fetch(FetchDescriptor<VehicleProfile>())
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.filter(\.isDefault).count, 1, "exactly one default after delete+promote")
        XCTAssertEqual(all.first?.name, "B")
    }
}
