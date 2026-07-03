//
//  TripQueryParserTests.swift
//  aigosTests
//
//  Locks down the offline natural-language parser used by "Talk to aigos"
//  (Section 7, Feature 07).
//

import XCTest
@testable import aigos

final class TripQueryParserTests: XCTestCase {

    private func vehicle(_ name: String) -> VehicleProfile {
        VehicleProfile(name: name, type: .car, fuelType: .premium95, efficiencyKmL: 14.5)
    }

    func testSpecExampleWithVehicle() {
        let q = TripQueryParser.parse(
            "How much to drive Pampanga to Manila in my Vios?",
            vehicles: [vehicle("My Vios")]
        )
        XCTAssertEqual(q?.origin, "pampanga")
        XCTAssertEqual(q?.destination, "manila")
        XCTAssertEqual(q?.vehicleName, "My Vios")
    }

    func testSimpleXtoY() {
        let q = TripQueryParser.parse("manila to batangas", vehicles: [])
        XCTAssertEqual(q?.origin, "manila")
        XCTAssertEqual(q?.destination, "batangas")
        XCTAssertNil(q?.vehicleName)
    }

    func testMultiWordDestination() {
        let q = TripQueryParser.parse("cost from makati to cagayan de oro", vehicles: [])
        XCTAssertEqual(q?.origin, "makati")
        XCTAssertEqual(q?.destination, "cagayan de oro")
    }

    func testMultiWordOrigin() {
        let q = TripQueryParser.parse("quezon city to batangas", vehicles: [])
        XCTAssertEqual(q?.origin, "quezon city")
        XCTAssertEqual(q?.destination, "batangas")
    }

    func testReversedPhrasing() {
        let q = TripQueryParser.parse("how much to get to manila from pampanga", vehicles: [])
        XCTAssertEqual(q?.origin, "pampanga")
        XCTAssertEqual(q?.destination, "manila")
    }

    func testDoesNotMergeAdjacentPlaces() {
        let q = TripQueryParser.parse("drive to tagaytay from makati in my Vios", vehicles: [vehicle("My Vios")])
        XCTAssertEqual(q?.origin, "makati")
        XCTAssertEqual(q?.destination, "tagaytay")   // not "tagaytay makati"
    }

    func testBetweenAndPhrasing() {
        let q = TripQueryParser.parse("fuel between manila and cebu", vehicles: [])
        XCTAssertEqual(q?.origin, "manila")
        XCTAssertEqual(q?.destination, "cebu")
    }

    func testProvinceAlias() {
        let q = TripQueryParser.parse("pampanga to bulacan", vehicles: [])
        XCTAssertEqual(q?.origin, "pampanga")
        XCTAssertEqual(q?.destination, "bulacan")
    }

    func testNonTripReturnsNil() {
        XCTAssertNil(TripQueryParser.parse("what's the weather today", vehicles: []))
        XCTAssertNil(TripQueryParser.parse("hello aigos", vehicles: []))
        XCTAssertNil(TripQueryParser.parse("", vehicles: []))
    }

    func testUnknownPlacesReturnNil() {
        XCTAssertNil(TripQueryParser.parse("narnia to mordor", vehicles: []))
    }
}
