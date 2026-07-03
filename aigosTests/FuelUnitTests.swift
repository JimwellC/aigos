//
//  FuelUnitTests.swift
//  aigosTests
//
//  The Settings fuel-unit toggle: display/input conversion around the canonical
//  km/L storage must be correct and lossless.
//

import XCTest
@testable import aigos

final class FuelUnitTests: XCTestCase {

    func testKmPerLIsIdentity() {
        XCTAssertEqual(FuelUnit.kmPerL.displayValue(fromKmL: 14.5), 14.5, accuracy: 0.0001)
        XCTAssertEqual(FuelUnit.kmPerL.kmL(fromDisplay: 14.5), 14.5, accuracy: 0.0001)
    }

    func testL100Conversion() {
        // 14.5 km/L displays as ~6.9 L/100km.
        XCTAssertEqual(FuelUnit.lPer100km.displayValue(fromKmL: 14.5), 100.0 / 14.5, accuracy: 0.0001)
        // Entering 8 L/100km stores as 12.5 km/L.
        XCTAssertEqual(FuelUnit.lPer100km.kmL(fromDisplay: 8), 12.5, accuracy: 0.0001)
    }

    func testDisplayInputRoundTrip() {
        for unit in FuelUnit.allCases {
            for kmL in stride(from: 4.0, through: 30.0, by: 0.5) {
                let shown = unit.displayValue(fromKmL: kmL)
                let stored = unit.kmL(fromDisplay: shown)
                XCTAssertEqual(stored, kmL, accuracy: 1e-9, "\(unit.label) round-trip at \(kmL)")
            }
        }
    }

    func testFormatting() {
        XCTAssertEqual(FuelUnit.kmPerL.format(kmL: 14.5), "14.5 km/L")
        XCTAssertEqual(FuelUnit.lPer100km.format(kmL: 14.5), "6.9 L/100km")   // 100/14.5 = 6.90
    }

    func testDefaultInputsAreValidAndSimilar() {
        for unit in FuelUnit.allCases {
            let value = Double(unit.defaultInput)
            XCTAssertNotNil(value, "\(unit.label) default must parse")
            XCTAssertGreaterThan(value ?? 0, 0)
        }
        // Both defaults describe roughly the same economy (~12 km/L).
        let kmLDefault = FuelUnit.kmPerL.kmL(fromDisplay: Double(FuelUnit.kmPerL.defaultInput)!)
        let l100Default = FuelUnit.lPer100km.kmL(fromDisplay: Double(FuelUnit.lPer100km.defaultInput)!)
        XCTAssertEqual(kmLDefault, l100Default, accuracy: 0.3)
    }
}
