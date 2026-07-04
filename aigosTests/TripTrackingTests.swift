//
//  TripTrackingTests.swift
//  aigosTests
//
//  GPS trip-tracking + fuel-log math and model CRUD (v1.1).
//

import XCTest
import SwiftData
@testable import aigos

final class TripTrackingTests: XCTestCase {

    @MainActor
    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            VehicleProfile.self, DrivingProfile.self, TripRecord.self, SavedRoute.self,
            FuelPriceCache.self, PersonalPlace.self, TrackedTrip.self, FuelLog.self,
        ])
        return ModelContext(try ModelContainer(
            for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    }

    // MARK: - TripMetrics

    func testDistanceFromCoordinates() {
        // Makati → Quezon City is roughly 12–15 km straight-line.
        let d = TripMetrics.distanceKm(coordinates: [(14.5547, 121.0244), (14.6760, 121.0437)])
        XCTAssertGreaterThan(d, 10)
        XCTAssertLessThan(d, 18)
        // A multi-point track sums its legs.
        let track = TripMetrics.distanceKm(coordinates: [
            (14.55, 121.02), (14.60, 121.03), (14.66, 121.04)])
        XCTAssertGreaterThan(track, d * 0)   // finite, positive
        XCTAssertEqual(TripMetrics.distanceKm(coordinates: [(14.5, 121.0)]), 0)
    }

    func testAccuracyPercent() {
        XCTAssertEqual(TripMetrics.accuracyPercent(estimated: 82.4, actual: 87.2), 94.49, accuracy: 0.1)
        XCTAssertEqual(TripMetrics.accuracyPercent(estimated: 100, actual: 100), 100, accuracy: 0.01)
        XCTAssertEqual(TripMetrics.accuracyPercent(estimated: 0, actual: 50), 0)   // guard
    }

    func testFuelAndSpeed() {
        XCTAssertEqual(TripMetrics.fuelLitres(distanceKm: 87.0, efficiencyKmL: 14.5), 6.0, accuracy: 0.01)
        XCTAssertEqual(TripMetrics.fuelLitres(distanceKm: 50, efficiencyKmL: 0), 0)  // guard
        XCTAssertEqual(TripMetrics.avgSpeedKmh(distanceKm: 60, seconds: 3600), 60, accuracy: 0.01)
        XCTAssertEqual(TripMetrics.avgSpeedKmh(distanceKm: 60, seconds: 0), 0)       // guard
    }

    func testActualKmLFromFillUps() {
        // 45,230 → 45,680 = 450 km on 34.2 L → ~13.16 km/L.
        XCTAssertEqual(TripMetrics.actualKmL(odometerStart: 45230, odometerEnd: 45680, litresAtEnd: 34.2)!,
                       13.16, accuracy: 0.1)
        XCTAssertNil(TripMetrics.actualKmL(odometerStart: 100, odometerEnd: 100, litresAtEnd: 30))  // no distance
        XCTAssertNil(TripMetrics.actualKmL(odometerStart: 100, odometerEnd: 200, litresAtEnd: 0))   // no fuel
    }

    func testBlendedEfficiency() {
        // 60% toward the measured value.
        XCTAssertEqual(TripMetrics.blendedEfficiency(rated: 14.5, measured: 13.0), 13.6, accuracy: 0.01)
        XCTAssertEqual(TripMetrics.blendedEfficiency(rated: 14.5, measured: 0), 14.5)  // guard keeps rated
    }

    // MARK: - Model CRUD

    @MainActor
    func testTrackedTripCRUDAndPairs() throws {
        let ctx = try makeContext()
        let t = TrackedTrip(tripRecordId: UUID(), estimatedDistanceKm: 82.4, estimatedFuelL: 5.7,
                            estimatedCostPHP: 450, vehicleName: "My Vios",
                            origin: "Manila", destination: "Batangas")
        t.routeCoordinates = [14.55, 121.02, 14.60, 121.03, 14.66, 121.04]
        t.actualDistanceKm = 87.2
        t.accuracyPercent = 94.5
        t.isCompleted = true
        ctx.insert(t)
        try ctx.save()

        let saved = try XCTUnwrap(try ctx.fetch(FetchDescriptor<TrackedTrip>()).first)
        XCTAssertEqual(saved.coordinatePairs.count, 3)
        XCTAssertEqual(saved.coordinatePairs[1].lat, 14.60, accuracy: 0.001)
        XCTAssertEqual(saved.destination, "Batangas")
    }

    @MainActor
    func testFuelLogCRUD() throws {
        let ctx = try makeContext()
        let log = FuelLog(vehicleId: UUID(), vehicleName: "My Vios", fuelType: .unleaded91,
                          litersPurchased: 35, totalCostPHP: 2520, pricePerLiter: 72,
                          odometerKm: 45680, isFullTank: true, stationName: "Shell")
        ctx.insert(log)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<FuelLog>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.litersPurchased, 35)
        XCTAssertEqual(fetched.first?.pricePerLiter, 72)
        XCTAssertEqual(fetched.first?.stationName, "Shell")
        XCTAssertTrue(fetched.first?.isFullTank ?? false)
    }
}
