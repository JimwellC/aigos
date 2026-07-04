//
//  TrafficLoadFuelTests.swift
//  aigosTests
//
//  New estimator factors: traffic condition, vehicle load, and the low-fuel
//  warning. Plus the NL parser's detection of these conditions.
//

import XCTest
@testable import aigos

final class TrafficLoadFuelTests: XCTestCase {

    // MARK: - AC 3-state factor

    func testACUsageFactors() {
        XCTAssertEqual(ACUsage.always.acFactor, 1.12)
        XCTAssertEqual(ACUsage.sometimes.acFactor, 1.06)   // halfway
        XCTAssertEqual(ACUsage.off.acFactor, 1.0)
    }

    func testACUsageOverridesBinaryInEngine() {
        func est(_ ac: ACUsage?) -> FuelEstimate {
            CalculationEngine.estimate(
                distanceKm: 100, baseEfficiencyKmL: 15, fuelPricePerLitre: 70,
                avgHighwaySpeedKmh: 90, avgCitySpeedKmh: 40, acInUse: true,
                roadType: .highway, acUsage: ac)
        }
        XCTAssertEqual(est(nil).acFactor, 1.12)          // falls back to binary
        XCTAssertEqual(est(.always).acFactor, 1.12)
        XCTAssertEqual(est(.sometimes).acFactor, 1.06)
        XCTAssertEqual(est(.off).acFactor, 1.0)
        // "Sometimes" must land strictly between Off and Always.
        XCTAssertLessThan(est(.sometimes).estimatedCost, est(.always).estimatedCost)
        XCTAssertGreaterThan(est(.sometimes).estimatedCost, est(.off).estimatedCost)
    }

    // MARK: - Multiplier tables

    func testTrafficFactors() {
        XCTAssertEqual(TrafficCondition.light.factor, 1.00)
        XCTAssertEqual(TrafficCondition.moderate.factor, 1.08)
        XCTAssertEqual(TrafficCondition.heavy.factor, 1.25)
        XCTAssertEqual(TrafficCondition.standstill.factor, 1.35)
    }

    func testLoadFactors() {
        XCTAssertEqual(VehicleLoad.light.factor, 1.00)
        XCTAssertEqual(VehicleLoad.moderate.factor, 1.05)
        XCTAssertEqual(VehicleLoad.full.factor, 1.10)
        XCTAssertEqual(VehicleLoad.cargo.factor, 1.15)
    }

    func testFuelLevelFractions() {
        XCTAssertEqual(FuelLevel.full.fraction, 1.0)
        XCTAssertEqual(FuelLevel.threeQuarters.fraction, 0.75)
        XCTAssertEqual(FuelLevel.half.fraction, 0.5)
        XCTAssertEqual(FuelLevel.quarter.fraction, 0.25)
        XCTAssertEqual(FuelLevel.low.fraction, 0.10)
    }

    // MARK: - Factors applied to the estimate

    private func base(traffic: TrafficCondition = .light, load: VehicleLoad = .light,
                      road: RoadType = .highway, ac: Bool = false) -> FuelEstimate {
        CalculationEngine.estimate(
            distanceKm: 100, baseEfficiencyKmL: 10, fuelPricePerLitre: 60,
            avgHighwaySpeedKmh: 90, avgCitySpeedKmh: 40, acInUse: ac, roadType: road,
            traffic: traffic, load: load
        )
    }

    func testDefaultsAreNeutral() {
        // No traffic/load args → factors are 1.0 and the result is the baseline.
        let e = CalculationEngine.estimate(
            distanceKm: 100, baseEfficiencyKmL: 10, fuelPricePerLitre: 60,
            avgHighwaySpeedKmh: 90, avgCitySpeedKmh: 40, acInUse: false, roadType: .highway
        )
        XCTAssertEqual(e.trafficFactor, 1.0)
        XCTAssertEqual(e.loadFactor, 1.0)
        XCTAssertEqual(e.adjustedLitres, 10.0, accuracy: 0.0001)
    }

    func testTrafficRaisesConsumption() {
        XCTAssertEqual(base(traffic: .heavy).trafficFactor, 1.25)
        // 90 km/h optimal (1.0), no AC/road → multiplier == traffic factor.
        XCTAssertEqual(base(traffic: .heavy).adjustmentMultiplier, 1.25, accuracy: 0.0001)
        XCTAssertEqual(base(traffic: .standstill).adjustedLitres, 13.5, accuracy: 0.0001)
    }

    func testLoadRaisesConsumption() {
        XCTAssertEqual(base(load: .cargo).loadFactor, 1.15)
        XCTAssertEqual(base(load: .cargo).adjustedLitres, 11.5, accuracy: 0.0001)
    }

    /// Full combination: city road @ 35 km/h city, AC on, heavy traffic, 3–4 pax.
    func testAllFactorsCombine() {
        let e = CalculationEngine.estimate(
            distanceKm: 82.4, baseEfficiencyKmL: 14.5, fuelPricePerLitre: 62.55,
            avgHighwaySpeedKmh: 110, avgCitySpeedKmh: 35, acInUse: true, roadType: .city,
            traffic: .heavy, load: .moderate
        )
        // 1.18 (city speed) × 1.12 (AC) × 1.20 (city road) × 1.25 (heavy) × 1.05 (load)
        let expected = 1.18 * 1.12 * 1.20 * 1.25 * 1.05
        XCTAssertEqual(e.speedFactor, 1.18)
        XCTAssertEqual(e.roadFactor, 1.20)
        XCTAssertEqual(e.trafficFactor, 1.25)
        XCTAssertEqual(e.loadFactor, 1.05)
        XCTAssertEqual(e.adjustmentMultiplier, expected, accuracy: 0.00001)
        XCTAssertEqual(e.estimatedCost, (82.4 / 14.5) * expected * 62.55, accuracy: 0.01)
    }

    // MARK: - Low-fuel warning

    func testRefuelWarning() {
        // Needs ~13.5 L; a near-empty tank (5 L) triggers the warning.
        let low = base(traffic: .standstill).with(availableFuel: 5)
        XCTAssertTrue(low.needsRefuel)
        // A full tank (40 L) does not.
        let ok = base(traffic: .standstill).with(availableFuel: 40)
        XCTAssertFalse(ok.needsRefuel)
        // No fuel level supplied → never warns.
        XCTAssertFalse(base().needsRefuel)
    }

    func testTypicalTankLiters() {
        // Per-type default tank (also the manual-entry default): car 42, moto 5,
        // truck 75, van 65.
        XCTAssertEqual(VehicleType.car.typicalTankLiters, 42)
        XCTAssertEqual(VehicleType.motorcycle.typicalTankLiters, 5)
        XCTAssertGreaterThan(VehicleType.truck.typicalTankLiters, VehicleType.van.typicalTankLiters)
    }

    // MARK: - NL detection

    func testParserDetectsHeavyTraffic() {
        let q = TripQueryParser.parse("manila to batangas with heavy traffic", vehicles: [])
        XCTAssertEqual(q?.origin, "manila")
        XCTAssertEqual(q?.destination, "batangas")
        XCTAssertEqual(q?.traffic, .heavy)
    }

    func testParserDetectsEDSAAsStandstill() {
        let q = TripQueryParser.parse("makati to manila on edsa", vehicles: [])
        XCTAssertEqual(q?.destination, "manila")
        XCTAssertEqual(q?.traffic, .standstill)
    }

    func testParserDetectsRushHourAndAC() {
        let q = TripQueryParser.parse("makati to tagaytay during rush hour with ac on", vehicles: [])
        XCTAssertEqual(q?.origin, "makati")
        XCTAssertEqual(q?.destination, "tagaytay")
        XCTAssertEqual(q?.rushHour, true)
        XCTAssertEqual(q?.acOn, true)
    }

    func testParserDetectsNoAC() {
        let q = TripQueryParser.parse("manila to cebu no aircon", vehicles: [])
        XCTAssertEqual(q?.acOn, false)
    }

    func testParserDetectsCargo() {
        let q = TripQueryParser.parse("manila to batangas with cargo", vehicles: [])
        XCTAssertEqual(q?.load, .cargo)
    }

    func testNoConditionsMeansNilHints() {
        let q = TripQueryParser.parse("manila to batangas", vehicles: [])
        XCTAssertNil(q?.traffic)
        XCTAssertNil(q?.acOn)
        XCTAssertNil(q?.rushHour)
        XCTAssertNil(q?.load)
    }

    func testDestinationOnlyUsesHomeShortcut() {
        let home = [PersonalPlace(name: "Home", gazetteerKey: "makati")]
        let q = TripQueryParser.parse("how much to drive to Tagaytay during rush hour?",
                                      vehicles: [], personalPlaces: home)
        XCTAssertEqual(q?.origin, "home")
        XCTAssertEqual(q?.destination, "tagaytay")
        XCTAssertEqual(q?.rushHour, true)
    }
}

private extension FuelEstimate {
    /// Rebuild with a supplied available-fuel figure (for warning tests).
    func with(availableFuel: Double) -> FuelEstimate {
        FuelEstimate(
            distanceKm: distanceKm, baseEfficiencyKmL: baseEfficiencyKmL, baseLitres: baseLitres,
            speedFactor: speedFactor, acFactor: acFactor, roadFactor: roadFactor,
            trafficFactor: trafficFactor, loadFactor: loadFactor,
            adjustmentMultiplier: adjustmentMultiplier,
            ageFactor: ageFactor, maintenanceFactor: maintenanceFactor,
            weatherFactor: weatherFactor, roadSurfaceFactor: roadSurfaceFactor,
            efficiencyMultiplier: efficiencyMultiplier, ageYears: ageYears,
            maintenance: maintenance, weather: weather, roadSurface: roadSurface,
            adjustedEfficiencyKmL: adjustedEfficiencyKmL,
            adjustedLitres: adjustedLitres, fuelPricePerLitre: fuelPricePerLitre,
            estimatedCost: estimatedCost, availableFuelLitres: availableFuel
        )
    }
}
