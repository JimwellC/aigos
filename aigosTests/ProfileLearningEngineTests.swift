//
//  ProfileLearningEngineTests.swift
//  aigosTests
//
//  Verifies the self-learning rolling average, AC-usage rate, and confidence
//  progression (Section 14C).
//

import XCTest
@testable import aigos

final class ProfileLearningEngineTests: XCTestCase {

    func testRollingAvg() {
        XCTAssertEqual(ProfileLearningEngine.rollingAvg(existing: 108, new: 130, weight: 10), 110.2, accuracy: 0.0001)
        XCTAssertEqual(ProfileLearningEngine.rollingAvg(existing: 90, new: 90, weight: 1), 90, accuracy: 0.0001)
        // weight 1 always returns the new sample.
        XCTAssertEqual(ProfileLearningEngine.rollingAvg(existing: 50, new: 130, weight: 1), 130, accuracy: 0.0001)
        // guarded weight
        XCTAssertEqual(ProfileLearningEngine.rollingAvg(existing: 50, new: 130, weight: 0), 130, accuracy: 0.0001)
    }

    func testFirstTripSeedsLearnedAverages() {
        let profile = DrivingProfile(vehicleId: UUID())
        let trip = makeTrip(highway: 120, city: 30, acOn: true)

        ProfileLearningEngine.updateProfile(profile, with: trip)

        XCTAssertEqual(profile.tripCount, 1)
        XCTAssertEqual(profile.avgActualHighwaySpeed ?? -1, 120, accuracy: 0.0001)
        XCTAssertEqual(profile.avgActualCitySpeed ?? -1, 30, accuracy: 0.0001)
        XCTAssertEqual(profile.confidenceLevel, .new)
    }

    func testACUsageRate() {
        let profile = DrivingProfile(vehicleId: UUID())
        ProfileLearningEngine.updateProfile(profile, with: makeTrip(highway: 100, city: 40, acOn: true))
        XCTAssertEqual(profile.acUsageRate, 1.0, accuracy: 0.0001)     // 1/1
        ProfileLearningEngine.updateProfile(profile, with: makeTrip(highway: 100, city: 40, acOn: false))
        XCTAssertEqual(profile.acUsageRate, 0.5, accuracy: 0.0001)     // 1/2
        ProfileLearningEngine.updateProfile(profile, with: makeTrip(highway: 100, city: 40, acOn: false))
        XCTAssertEqual(profile.acUsageRate, 1.0 / 3.0, accuracy: 0.0001) // 1/3
    }

    func testConfidenceProgression() {
        let profile = DrivingProfile(vehicleId: UUID())
        for _ in 0..<4 { ProfileLearningEngine.updateProfile(profile, with: makeTrip(highway: 100, city: 40, acOn: true)) }
        XCTAssertEqual(profile.confidenceLevel, .new)            // 4 trips
        ProfileLearningEngine.updateProfile(profile, with: makeTrip(highway: 100, city: 40, acOn: true))
        XCTAssertEqual(profile.confidenceLevel, .building)       // 5 trips
        for _ in 0..<10 { ProfileLearningEngine.updateProfile(profile, with: makeTrip(highway: 100, city: 40, acOn: true)) }
        XCTAssertEqual(profile.confidenceLevel, .confident)      // 15 trips
    }

    func testRollingAverageConvergesTowardRecent() {
        let profile = DrivingProfile(vehicleId: UUID())
        // Seed with slow trips, then repeatedly log fast ones — average should climb.
        for _ in 0..<10 { ProfileLearningEngine.updateProfile(profile, with: makeTrip(highway: 80, city: 40, acOn: true)) }
        let before = profile.avgActualHighwaySpeed ?? 0
        for _ in 0..<10 { ProfileLearningEngine.updateProfile(profile, with: makeTrip(highway: 130, city: 40, acOn: true)) }
        let after = profile.avgActualHighwaySpeed ?? 0
        XCTAssertGreaterThan(after, before)
        XCTAssertLessThanOrEqual(after, 130)
    }

    // MARK: - Helpers

    private func makeTrip(highway: Double, city: Double, acOn: Bool) -> TripRecord {
        let estimate = CalculationEngine.estimate(
            distanceKm: 50, baseEfficiencyKmL: 12, fuelPricePerLitre: 60,
            avgHighwaySpeedKmh: highway, avgCitySpeedKmh: city, acInUse: acOn, roadType: .highway
        )
        return TripRecord(
            origin: "A", destination: "B", vehicleName: "Test", fuelType: .premium95,
            estimate: estimate, avgHighwaySpeed: highway, avgCitySpeed: city,
            roadType: .highway, acWasOn: acOn
        )
    }
}
