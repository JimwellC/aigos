//
//  FuelLogParserTests.swift
//  aigosTests
//
//  Parsing "I just filled up …" from Talk into a FuelLogDraft (v1.1).
//

import XCTest
@testable import aigos

final class FuelLogParserTests: XCTestCase {

    func testFullSentence() {
        let d = FuelLogParser.parse("I just filled up 35 liters at Shell for 2,520 pesos")
        XCTAssertEqual(d?.liters, 35)
        XCTAssertEqual(d?.totalCost, 2520)
        XCTAssertEqual(d?.stationName, "Shell")
    }

    func testShortFormsAndUnitL() {
        // "up 30L" must not be misread as cost 30.
        let d = FuelLogParser.parse("filled up 30L for php 2100")
        XCTAssertEqual(d?.liters, 30)
        XCTAssertEqual(d?.totalCost, 2100)
    }

    func testMultiWordStation() {
        let d = FuelLogParser.parse("gassed up at Petron San Fernando for 3000")
        XCTAssertEqual(d?.stationName, "Petron San Fernando")
        XCTAssertEqual(d?.totalCost, 3000)
    }

    func testNonFuelMessageIgnored() {
        XCTAssertNil(FuelLogParser.parse("Manila to Batangas"))
        XCTAssertFalse(FuelLogParser.isFuelLog("what's my mileage?"))
        XCTAssertTrue(FuelLogParser.isFuelLog("I just filled up"))
    }
}
