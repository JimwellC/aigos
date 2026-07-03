//
//  CalculationEngineTests.swift
//  aigosTests
//
//  Locks down the core physics formula (Section 8) and speed-factor table
//  (Section 14E) against the spec's worked examples.
//

import XCTest
@testable import aigos

final class CalculationEngineTests: XCTestCase {

    func testSpeedFactorTable() {
        XCTAssertEqual(CalculationEngine.speedFactor(forSpeed: 45), 1.18)
        XCTAssertEqual(CalculationEngine.speedFactor(forSpeed: 59.9), 1.18)
        XCTAssertEqual(CalculationEngine.speedFactor(forSpeed: 60), 1.08)
        XCTAssertEqual(CalculationEngine.speedFactor(forSpeed: 79), 1.08)
        XCTAssertEqual(CalculationEngine.speedFactor(forSpeed: 80), 1.00)   // optimal zone
        XCTAssertEqual(CalculationEngine.speedFactor(forSpeed: 99), 1.00)
        XCTAssertEqual(CalculationEngine.speedFactor(forSpeed: 100), 1.13)
        XCTAssertEqual(CalculationEngine.speedFactor(forSpeed: 119), 1.13)
        XCTAssertEqual(CalculationEngine.speedFactor(forSpeed: 120), 1.22)
        XCTAssertEqual(CalculationEngine.speedFactor(forSpeed: 160), 1.22)
    }

    func testRelevantSpeedByRoadType() {
        XCTAssertEqual(CalculationEngine.relevantSpeed(roadType: .city, highway: 110, city: 35), 35)
        XCTAssertEqual(CalculationEngine.relevantSpeed(roadType: .highway, highway: 110, city: 35), 110)
        XCTAssertEqual(CalculationEngine.relevantSpeed(roadType: .mountain, highway: 110, city: 35), 110)
    }

    /// The spec's worked example (Section 14D): 82.4 km, 14.5 km/L, PHP 62.55/L,
    /// 110 km/h highway, AC on, highway road.
    func testSpecWorkedExample() {
        let e = CalculationEngine.estimate(
            distanceKm: 82.4, baseEfficiencyKmL: 14.5, fuelPricePerLitre: 62.55,
            avgHighwaySpeedKmh: 110, avgCitySpeedKmh: 40, acInUse: true, roadType: .highway
        )
        XCTAssertEqual(e.speedFactor, 1.13)
        XCTAssertEqual(e.acFactor, 1.12)
        XCTAssertEqual(e.roadFactor, 1.00)
        XCTAssertEqual(e.adjustmentMultiplier, 1.2656, accuracy: 0.0001)
        XCTAssertEqual(e.baseLitres, 5.68, accuracy: 0.05)      // ~5.7 L
        XCTAssertEqual(e.adjustedLitres, 7.19, accuracy: 0.05)  // ~7.2 L
        XCTAssertEqual(e.estimatedCost, 449.87, accuracy: 0.5)  // ~PHP 450
    }

    func testACAndRoadFactors() {
        let noAC = CalculationEngine.estimate(
            distanceKm: 100, baseEfficiencyKmL: 10, fuelPricePerLitre: 60,
            avgHighwaySpeedKmh: 90, avgCitySpeedKmh: 40, acInUse: false, roadType: .highway
        )
        XCTAssertEqual(noAC.acFactor, 1.0)
        XCTAssertEqual(noAC.roadFactor, 1.0)
        XCTAssertEqual(noAC.speedFactor, 1.0)             // 90 km/h optimal
        XCTAssertEqual(noAC.adjustedLitres, 10.0, accuracy: 0.0001)

        let mountainAC = CalculationEngine.estimate(
            distanceKm: 100, baseEfficiencyKmL: 10, fuelPricePerLitre: 60,
            avgHighwaySpeedKmh: 90, avgCitySpeedKmh: 40, acInUse: true, roadType: .mountain
        )
        XCTAssertEqual(mountainAC.roadFactor, 1.35)
        XCTAssertEqual(mountainAC.adjustmentMultiplier, 1.0 * 1.12 * 1.35, accuracy: 0.0001)
    }

    func testCityUsesCitySpeed() {
        // City road at 35 km/h city speed -> 1.18 speed factor, 1.20 road factor.
        let e = CalculationEngine.estimate(
            distanceKm: 50, baseEfficiencyKmL: 12, fuelPricePerLitre: 60,
            avgHighwaySpeedKmh: 110, avgCitySpeedKmh: 35, acInUse: false, roadType: .city
        )
        XCTAssertEqual(e.speedFactor, 1.18)
        XCTAssertEqual(e.roadFactor, 1.20)
    }

    func testL100kmConversion() {
        XCTAssertEqual(CalculationEngine.kmL(fromL100: 8), 12.5, accuracy: 0.0001)
        XCTAssertEqual(CalculationEngine.kmL(fromL100: 0), 0)   // guarded
    }

    func testZeroEfficiencyIsGuarded() {
        // Should not divide-by-zero / produce NaN.
        let e = CalculationEngine.estimate(
            distanceKm: 100, baseEfficiencyKmL: 0, fuelPricePerLitre: 60,
            avgHighwaySpeedKmh: 90, avgCitySpeedKmh: 40, acInUse: false, roadType: .highway
        )
        XCTAssertFalse(e.estimatedCost.isNaN)
        XCTAssertFalse(e.estimatedCost.isInfinite)
    }

    func testFactorLitresContribution() {
        let e = CalculationEngine.estimate(
            distanceKm: 82.4, baseEfficiencyKmL: 14.5, fuelPricePerLitre: 62.55,
            avgHighwaySpeedKmh: 110, avgCitySpeedKmh: 40, acInUse: true, roadType: .highway
        )
        // A baseline (1.0) factor contributes zero litres.
        XCTAssertEqual(e.litres(forFactor: 1.0), 0, accuracy: 0.0001)
        // Speed +13% contributes ~0.74 L over the 5.68 L base.
        XCTAssertEqual(e.litres(forFactor: e.speedFactor), 5.68 * 0.13, accuracy: 0.05)
    }
}
