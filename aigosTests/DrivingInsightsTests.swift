//
//  DrivingInsightsTests.swift
//  aigosTests
//
//  Driving score + personalized suggestion engine (Feature 4).
//

import XCTest
@testable import aigos

final class DrivingInsightsTests: XCTestCase {

    // MARK: - DrivingScorer

    func testPerfectDriverScores100() {
        let s = DrivingScorer.score(highwaySpeedKmh: 90, acUsageRate: 0, rushHourFraction: 0,
                                    maintenance: .wellMaintained, gpsSmoothness: 1.0)
        XCTAssertEqual(s.speed, 30)
        XCTAssertEqual(s.ac, 15)
        XCTAssertEqual(s.smoothness, 15)
        XCTAssertEqual(s.rushHour, 20)
        XCTAssertEqual(s.maintenance, 20)
        XCTAssertEqual(s.total, 100)
        XCTAssertEqual(s.label, "🏆 Fuel Master")
    }

    func testPoorDriverScoresLow() {
        let s = DrivingScorer.score(highwaySpeedKmh: 130, acUsageRate: 1, rushHourFraction: 1,
                                    maintenance: .overduePMS, gpsSmoothness: nil)
        XCTAssertLessThan(s.speed, 8)          // >120 km/h factor 1.22
        XCTAssertEqual(s.ac, 9)                // 15 × (1 − 0.4)
        XCTAssertEqual(s.smoothness, 11)       // neutral (no GPS data)
        XCTAssertEqual(s.rushHour, 0)
        XCTAssertEqual(s.maintenance, 5)
        XCTAssertLessThan(s.total, 60)
        XCTAssertEqual(s.label, "📈 Room to Improve")
    }

    func testScoreLabelBoundaries() {
        func label(_ total: Int) -> String {
            // speed carries the whole total; others 0.
            DrivingScore(speed: min(total, 30), ac: max(0, min(total - 30, 15)),
                         smoothness: max(0, min(total - 45, 15)),
                         rushHour: max(0, min(total - 60, 20)),
                         maintenance: max(0, min(total - 80, 20))).label
        }
        XCTAssertEqual(label(90), "🏆 Fuel Master")
        XCTAssertEqual(label(75), "⭐ Smart Driver")
        XCTAssertEqual(label(60), "👍 Getting There")
        XCTAssertEqual(label(59), "📈 Room to Improve")
    }

    // MARK: - SuggestionEngine.pick (rotation + 7-day no-repeat)

    private func sug(_ t: SuggestionType) -> Suggestion {
        Suggestion(type: t, icon: "", title: t.rawValue, detail: "", savingsPHP: 0)
    }
    private let day0 = Date(timeIntervalSince1970: 1_700_000_000)

    func testPickLimitsToThree() {
        let all = [sug(.speed), sug(.ac), sug(.timing), sug(.maintenance), sug(.fuelType)]
        let picked = SuggestionEngine.pick(all, recentlyShownAt: [:], now: day0, limit: 3)
        XCTAssertEqual(picked.count, 3)
    }

    func testRecentlyShownExcludedWithinSevenDays() {
        let all = [sug(.speed), sug(.ac), sug(.timing), sug(.maintenance), sug(.fuelType)]
        // speed + ac shown 2 days ago → should be de-prioritized (fresh ones fill first).
        let shown = ["speed": day0.addingTimeInterval(-2 * 86400),
                     "ac": day0.addingTimeInterval(-2 * 86400)]
        let picked = SuggestionEngine.pick(all, recentlyShownAt: shown, now: day0, limit: 3)
        XCTAssertEqual(picked.count, 3)
        XCTAssertFalse(picked.contains(sug(.speed)))
        XCTAssertFalse(picked.contains(sug(.ac)))
    }

    func testStaleAfterSevenDaysBecomesEligible() {
        let all = [sug(.speed), sug(.ac)]
        let shown = ["speed": day0.addingTimeInterval(-8 * 86400)]   // 8 days ago → fresh again
        let picked = SuggestionEngine.pick(all, recentlyShownAt: shown, now: day0, limit: 3)
        XCTAssertTrue(picked.contains(sug(.speed)))
    }

    func testRotationChangesAcrossDays() {
        let all = [sug(.speed), sug(.ac), sug(.timing), sug(.maintenance), sug(.fuelType)]
        let d1 = SuggestionEngine.pick(all, recentlyShownAt: [:], now: day0, limit: 2)
        let d2 = SuggestionEngine.pick(all, recentlyShownAt: [:], now: day0.addingTimeInterval(86400), limit: 2)
        // Different day → the rotated window should differ for at least one slot.
        XCTAssertNotEqual(d1.map(\.id), d2.map(\.id))
    }

    // MARK: - SuggestionEngine.candidates

    func testCandidatesForInefficientVehicle() throws {
        let profile = DrivingProfile()
        profile.avgActualHighwaySpeed = 120     // fast → speed tip
        profile.acUsageRate = 1.0               // heavy AC → ac tip
        let v = VehicleProfile(name: "My Car", type: .car, fuelType: .premium95,
                               efficiencyKmL: 14, tankCapacityL: 45,
                               maintenanceStatus: .overduePMS, drivingProfile: profile)
        // 4 recent trips, all rush hour, with real cost.
        let now = Date()
        let trips = (0..<4).map { i -> TripRecord in
            let est = CalculationEngine.estimate(distanceKm: 40, baseEfficiencyKmL: 14, fuelPricePerLitre: 65,
                                                 avgHighwaySpeedKmh: 120, avgCitySpeedKmh: 40, acInUse: true, roadType: .highway)
            let t = TripRecord(origin: "A", destination: "B", vehicleName: "My Car", fuelType: .premium95,
                               estimate: est, avgHighwaySpeed: 120, avgCitySpeed: 40, roadType: .highway,
                               acWasOn: true, traffic: .heavy, wasRushHour: true)
            t.totalCostPHP = 200; t.adjustedLitres = 3; t.calculatedAt = now.addingTimeInterval(Double(-i) * 86400)
            return t
        }
        let cands = SuggestionEngine.candidates(vehicle: v, trips: trips, now: now,
                                                currentFuelPrice: 65, unleaded91Price: 60)
        let types = Set(cands.map(\.type))
        XCTAssertTrue(types.contains(.speed))
        XCTAssertTrue(types.contains(.ac))
        XCTAssertTrue(types.contains(.timing))
        XCTAssertTrue(types.contains(.maintenance))
        XCTAssertTrue(types.contains(.fuelType))
        // Fuel-type saving = (65 − 60) × 45 = PHP 225/tank.
        let fuelSaving = try XCTUnwrap(cands.first { $0.type == .fuelType }?.savingsPHP)
        XCTAssertEqual(fuelSaving, 225, accuracy: 0.01)
        // Every tip carries a positive saving.
        XCTAssertTrue(cands.allSatisfy { ($0.savingsPHP ?? 1) > 0 })
    }

    func testNoCandidatesForCleanEfficientVehicle() {
        let profile = DrivingProfile()
        profile.avgActualHighwaySpeed = 90      // optimal
        profile.acUsageRate = 0.2               // low AC
        let v = VehicleProfile(name: "Clean", type: .car, fuelType: .unleaded91,
                               efficiencyKmL: 20, maintenanceStatus: .wellMaintained, drivingProfile: profile)
        let cands = SuggestionEngine.candidates(vehicle: v, trips: [], now: Date(),
                                                currentFuelPrice: 60, unleaded91Price: 60)
        XCTAssertTrue(cands.isEmpty)
    }
}
