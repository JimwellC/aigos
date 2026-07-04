//
//  FuelReportTests.swift
//  aigosTests
//
//  Monthly fuel-report aggregation + fill-to-fill true efficiency (v1.1).
//

import XCTest
@testable import aigos

final class FuelReportTests: XCTestCase {

    private let cal = Calendar(identifier: .gregorian)

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    private func trip(_ origin: String, _ dest: String, cost: Double, km: Double, litres: Double, on: Date) -> TripRecord {
        let est = CalculationEngine.estimate(distanceKm: km, baseEfficiencyKmL: 14.5, fuelPricePerLitre: 60,
                                             avgHighwaySpeedKmh: 90, avgCitySpeedKmh: 40, acInUse: true, roadType: .highway)
        let t = TripRecord(origin: origin, destination: dest, vehicleName: "V", fuelType: .unleaded91,
                           estimate: est, avgHighwaySpeed: 90, avgCitySpeed: 40, roadType: .highway, acWasOn: true)
        t.totalCostPHP = cost; t.distanceKm = km; t.adjustedLitres = litres; t.calculatedAt = on
        return t
    }

    func testMonthlyAggregationAndTopTrips() {
        let trips = [
            trip("Home", "Office", cost: 85, km: 20, litres: 1.4, on: date(2026, 11, 2)),
            trip("Home", "Office", cost: 85, km: 20, litres: 1.4, on: date(2026, 11, 9)),
            trip("Manila", "Baguio", cost: 1240, km: 250, litres: 20, on: date(2026, 11, 15)),
            trip("Old", "Trip", cost: 500, km: 100, litres: 8, on: date(2026, 10, 20)),   // last month
        ]
        let r = FuelReport.monthly(for: date(2026, 11, 15), trips: trips, calendar: cal)
        XCTAssertEqual(r.tripCount, 3)
        XCTAssertEqual(r.totalSpentPHP, 1410, accuracy: 0.01)          // 85+85+1240
        XCTAssertEqual(r.totalDistanceKm, 290, accuracy: 0.01)
        XCTAssertEqual(r.mostExpensive?.title, "Manila → Baguio")
        XCTAssertEqual(r.cheapest?.title, "Home → Office")
        XCTAssertEqual(r.mostFrequent?.title, "Home → Office")
        XCTAssertEqual(r.mostFrequent?.count, 2)
        XCTAssertFalse(r.isEmpty)
        XCTAssertTrue(r.monthLabel.contains("November"))
    }

    func testMonthOverMonthDeltas() {
        let trips = [
            trip("A", "B", cost: 300, km: 50, litres: 4, on: date(2026, 11, 5)),
            trip("A", "B", cost: 200, km: 40, litres: 3, on: date(2026, 10, 5)),
            trip("C", "D", cost: 100, km: 20, litres: 2, on: date(2026, 10, 12)),
        ]
        let r = FuelReport.monthly(for: date(2026, 11, 5), trips: trips, calendar: cal)
        XCTAssertEqual(r.spendDeltaPHP!, 0, accuracy: 0.01)           // Nov 300 - Oct 300
        XCTAssertEqual(r.tripsDelta, -1)                              // 1 vs 2
    }

    func testEmptyMonth() {
        let r = FuelReport.monthly(for: date(2026, 12, 1), trips: [], calendar: cal)
        XCTAssertTrue(r.isEmpty)
        XCTAssertEqual(r.tripCount, 0)
        XCTAssertNil(r.mostExpensive)
    }

    func testTrueEfficiencyFromFullTankLogs() {
        let logs = [
            FuelLog(date: date(2026, 11, 1), vehicleId: UUID(), vehicleName: "V", fuelType: .unleaded91,
                    litersPurchased: 30, totalCostPHP: 2100, pricePerLiter: 70, odometerKm: 45230, isFullTank: true),
            FuelLog(date: date(2026, 11, 10), vehicleId: UUID(), vehicleName: "V", fuelType: .unleaded91,
                    litersPurchased: 34.2, totalCostPHP: 2400, pricePerLiter: 70, odometerKm: 45680, isFullTank: true),
        ]
        let eff = FuelReport.trueEfficiency(from: logs)
        XCTAssertNotNil(eff)
        XCTAssertEqual(eff!.distanceKm, 450, accuracy: 0.01)
        XCTAssertEqual(eff!.kmL, 13.16, accuracy: 0.1)
        // One log → not enough data.
        XCTAssertNil(FuelReport.trueEfficiency(from: [logs[0]]))
    }
}
