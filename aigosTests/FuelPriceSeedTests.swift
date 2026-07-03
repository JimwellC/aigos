//
//  FuelPriceSeedTests.swift
//  aigosTests
//
//  Guards the seeded DOE pump prices: internal sanity (octane ordering, plausible
//  range) plus the exact current set, so a weekly price update is always an
//  intentional, reviewed change rather than accidental drift.
//

import XCTest
@testable import aigos

final class FuelPriceSeedTests: XCTestCase {

    func testSeedPricesArePlausible() {
        for type in FuelType.allCases {
            XCTAssertGreaterThan(type.seedPrice, 30, "\(type.label) too low")
            XCTAssertLessThan(type.seedPrice, 120, "\(type.label) too high")
        }
    }

    func testOctaneOrdering() {
        // Higher octane costs more. (Diesel is NOT assumed cheapest — in current PH
        // rates it can sit above RON 91, so no diesel-vs-gasoline ordering here.)
        XCTAssertLessThan(FuelType.ron91.seedPrice, FuelType.ron95.seedPrice)
        XCTAssertLessThan(FuelType.ron95.seedPrice, FuelType.ron97.seedPrice)
    }

    /// Current DOE-tracked Metro Manila rates (week of 2026-06-30). Update these
    /// alongside the values in FuelPrices.json / Enums.swift on each price refresh.
    func testCurrentSeedValues() {
        XCTAssertEqual(FuelType.ron91.seedPrice, 56.65)
        XCTAssertEqual(FuelType.ron95.seedPrice, 58.15)
        XCTAssertEqual(FuelType.ron97.seedPrice, 60.80)
        XCTAssertEqual(FuelType.diesel.seedPrice, 56.74)
    }
}
