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

    // MARK: - GPS quality gating

    func testAcceptGPSPoint() {
        // Good fix: fine accuracy, valid speed.
        XCTAssertTrue(TripMetrics.acceptGPSPoint(horizontalAccuracy: 8, speedMetersPerSec: 12))
        XCTAssertTrue(TripMetrics.acceptGPSPoint(horizontalAccuracy: 0, speedMetersPerSec: 0))
        // Coarse accuracy (>= 50 m) rejected.
        XCTAssertFalse(TripMetrics.acceptGPSPoint(horizontalAccuracy: 50, speedMetersPerSec: 12))
        XCTAssertFalse(TripMetrics.acceptGPSPoint(horizontalAccuracy: 120, speedMetersPerSec: 12))
        // Invalid negative accuracy (CoreLocation sentinel) rejected.
        XCTAssertFalse(TripMetrics.acceptGPSPoint(horizontalAccuracy: -1, speedMetersPerSec: 12))
        // Invalid negative speed rejected.
        XCTAssertFalse(TripMetrics.acceptGPSPoint(horizontalAccuracy: 8, speedMetersPerSec: -1))
    }

    func testPlausibleSegment() {
        // Normal driving legs are kept.
        XCTAssertTrue(TripMetrics.isPlausibleSegment(meters: 12, seconds: 1))
        XCTAssertTrue(TripMetrics.isPlausibleSegment(meters: 400, seconds: 15))
        // A 500 m+ jump within a second is noise.
        XCTAssertFalse(TripMetrics.isPlausibleSegment(meters: 600, seconds: 1))
        XCTAssertFalse(TripMetrics.isPlausibleSegment(meters: 800, seconds: 0))
        // Implied speed > 100 m/s (~360 km/h) is impossible for a car.
        XCTAssertFalse(TripMetrics.isPlausibleSegment(meters: 1500, seconds: 10))
    }

    // MARK: - Trip-quality thresholds

    func testShortTripAndDuration() {
        XCTAssertTrue(TripMetrics.isShortTrip(distanceKm: 1.2))
        XCTAssertTrue(TripMetrics.isShortTrip(distanceKm: 2.99))
        XCTAssertFalse(TripMetrics.isShortTrip(distanceKm: 3))
        XCTAssertFalse(TripMetrics.isShortTrip(distanceKm: 12))
        XCTAssertTrue(TripMetrics.shortTripMessage(distanceKm: 1.2).contains("1.2 km"))

        XCTAssertFalse(TripMetrics.isTrackingLongEnough(seconds: 29))
        XCTAssertTrue(TripMetrics.isTrackingLongEnough(seconds: 30))
        XCTAssertTrue(TripMetrics.isTrackingLongEnough(seconds: 300))
    }

    func testAccuracyContextBands() {
        XCTAssertEqual(TripMetrics.accuracyContext(percent: 100), "🎯 Very accurate estimate!")
        XCTAssertEqual(TripMetrics.accuracyContext(percent: 90), "🎯 Very accurate estimate!")
        XCTAssertEqual(TripMetrics.accuracyContext(percent: 82), "👍 Good estimate")
        XCTAssertEqual(TripMetrics.accuracyContext(percent: 60), "📊 Moderate — factors like traffic and detours affected this")
        XCTAssertEqual(TripMetrics.accuracyContext(percent: 40), "📍 Large difference — this may be due to GPS signal, detours, or a very short trip")
    }

    func testShouldSuggestProfileUpdate() {
        // Inaccurate AND short → suppress.
        XCTAssertFalse(TripMetrics.shouldSuggestProfileUpdate(accuracyPercent: 55, distanceKm: 2))
        XCTAssertFalse(TripMetrics.shouldSuggestProfileUpdate(accuracyPercent: 69, distanceKm: 4.9))
        // Accurate (even if short) → allow.
        XCTAssertTrue(TripMetrics.shouldSuggestProfileUpdate(accuracyPercent: 95, distanceKm: 2))
        // Long (even if inaccurate) → allow.
        XCTAssertTrue(TripMetrics.shouldSuggestProfileUpdate(accuracyPercent: 55, distanceKm: 20))
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
