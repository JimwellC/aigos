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

    /// Current DOE rates via fuelprice.ph (week of Jun 30 – Jul 6, 2026). Update
    /// these alongside FuelPrices.json / Enums.swift on each price refresh.
    func testCurrentSeedValues() {
        XCTAssertEqual(FuelType.ron91.seedPrice, 72.00)
        XCTAssertEqual(FuelType.ron95.seedPrice, 73.00)
        XCTAssertEqual(FuelType.ron97.seedPrice, 76.00)
        XCTAssertEqual(FuelType.diesel.seedPrice, 69.10)
    }
}
