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
        // rates it can sit above Unleaded 91, so no diesel-vs-gasoline ordering here.)
        XCTAssertLessThan(FuelType.unleaded91.seedPrice, FuelType.premium95.seedPrice)
        XCTAssertLessThan(FuelType.premium95.seedPrice, FuelType.premium97.seedPrice)
    }

    /// Current DOE rates via fuelprice.ph / gaswatchph.com (week of Jun 30 – Jul 6,
    /// 2026). Update these alongside FuelPrices.json / Enums.swift on each refresh.
    func testCurrentSeedValues() {
        XCTAssertEqual(FuelType.unleaded91.seedPrice, 72.00)
        XCTAssertEqual(FuelType.premium95.seedPrice, 73.00)
        XCTAssertEqual(FuelType.premium97.seedPrice, 76.00)
        XCTAssertEqual(FuelType.diesel.seedPrice, 69.10)
        XCTAssertEqual(FuelType.premiumDiesel.seedPrice, 72.40)
        XCTAssertEqual(FuelType.eGasoline.seedPrice, 73.50)
    }

    func testLabelsMatchPumpNames() {
        XCTAssertEqual(FuelType.unleaded91.label, "Unleaded 91")
        XCTAssertEqual(FuelType.premium95.label, "Premium 95")
        XCTAssertEqual(FuelType.premium97.label, "Premium 97")
        XCTAssertEqual(FuelType.diesel.label, "Diesel")
        XCTAssertEqual(FuelType.premiumDiesel.label, "Premium Diesel")
        XCTAssertEqual(FuelType.eGasoline.label, "E-Gasoline")
    }

    func testDetectRecognisesOldAndNewNames() {
        XCTAssertEqual(FuelType.detect(in: "fill up with unleaded"), .unleaded91)
        XCTAssertEqual(FuelType.detect(in: "regular gas please"), .unleaded91)
        XCTAssertEqual(FuelType.detect(in: "ron 91"), .unleaded91)
        XCTAssertEqual(FuelType.detect(in: "premium"), .premium95)
        XCTAssertEqual(FuelType.detect(in: "ron 95"), .premium95)
        XCTAssertEqual(FuelType.detect(in: "ron 97"), .premium97)
        XCTAssertEqual(FuelType.detect(in: "just diesel"), .diesel)
        XCTAssertEqual(FuelType.detect(in: "premium diesel"), .premiumDiesel)
        XCTAssertEqual(FuelType.detect(in: "diesel plus"), .premiumDiesel)
        XCTAssertEqual(FuelType.detect(in: "e-gasoline"), .eGasoline)
        XCTAssertNil(FuelType.detect(in: "manila to baguio"))
    }
}
