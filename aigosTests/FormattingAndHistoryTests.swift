//
//  FormattingAndHistoryTests.swift
//  aigosTests
//
//  Currency formatting (must use the "PHP" prefix, never the ₱ glyph — Section 22)
//  and History month-over-month grouping.
//

import XCTest
@testable import aigos

final class FormattingTests: XCTestCase {

    func testPHPPrefixAndDecimals() {
        XCTAssertEqual(449.87.phpString, "PHP 449.87")
        XCTAssertEqual(62.5.phpString, "PHP 62.50")     // always two decimals
        XCTAssertEqual(0.0.phpString, "PHP 0.00")
        XCTAssertTrue(1234.5.phpString.hasPrefix("PHP "))
    }

    /// The peso glyph must never appear — "PHP" prefix only (Section 22, note 6).
    func testNeverUsesPesoGlyph() {
        let values = [0.0, 0.5, 62.55, 449.87, 1234.5, 1_000_000.0, -75.25]
        for v in values {
            let s = v.phpString
            XCTAssertFalse(s.contains("₱"), "\(s) must not contain the peso glyph")
            XCTAssertTrue(s.hasPrefix("PHP "), "\(s) must start with the PHP prefix")
        }
    }

    func testOneDecimal() {
        XCTAssertEqual(82.44.oneDecimal, "82.4")
        XCTAssertEqual(7.0.oneDecimal, "7.0")
    }

    func testFactorPercentString() {
        XCTAssertEqual(1.13.factorPercentString, "+13%")
        XCTAssertEqual(1.0.factorPercentString, "+0%")
        XCTAssertEqual(1.20.factorPercentString, "+20%")
        XCTAssertEqual(0.90.factorPercentString, "-10%")
    }
}

final class HistoryGroupingTests: XCTestCase {

    private func trip(cost: Double, at date: Date) -> TripRecord {
        let e = CalculationEngine.estimate(
            distanceKm: 10, baseEfficiencyKmL: 12, fuelPricePerLitre: 60,
            avgHighwaySpeedKmh: 90, avgCitySpeedKmh: 40, acInUse: false, roadType: .highway
        )
        let t = TripRecord(
            origin: "A", destination: "B", vehicleName: "T", fuelType: .ron95,
            estimate: e, avgHighwaySpeed: 90, avgCitySpeed: 40, roadType: .highway, acWasOn: false
        )
        t.totalCostPHP = cost
        t.calculatedAt = date
        return t
    }

    func testMonthTotalsAndGrouping() {
        let cal = Calendar.current
        let now = Date()
        let lastMonth = cal.date(byAdding: .month, value: -1, to: now)!
        let trips = [
            trip(cost: 100, at: now),
            trip(cost: 50, at: now),
            trip(cost: 200, at: lastMonth),
        ]

        XCTAssertEqual(MonthGroup.total(trips, monthsAgo: 0), 150, accuracy: 0.0001)
        XCTAssertEqual(MonthGroup.total(trips, monthsAgo: 1), 200, accuracy: 0.0001)

        let groups = MonthGroup.group(trips)
        XCTAssertEqual(groups.count, 2)
        // Newest month first, and it holds the two current-month trips.
        XCTAssertEqual(groups.first?.trips.count, 2)
        XCTAssertGreaterThan(groups[0].id, groups[1].id)
    }

    func testEmptyHistory() {
        XCTAssertEqual(MonthGroup.total([], monthsAgo: 0), 0)
        XCTAssertTrue(MonthGroup.group([]).isEmpty)
    }
}
