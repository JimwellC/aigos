//
//  FollowUpTests.swift
//  aigosTests
//
//  Conversational follow-ups: "same trip but it's EDSA on a Friday" layers new
//  conditions onto the previous trip.
//

import XCTest
@testable import aigos

final class FollowUpTests: XCTestCase {

    func testHintsFromBareText() {
        XCTAssertEqual(TripQueryParser.hints(from: "same trip but it's EDSA on a Friday").traffic, .standstill)
        XCTAssertEqual(TripQueryParser.hints(from: "what about with heavy traffic").traffic, .heavy)
        XCTAssertEqual(TripQueryParser.hints(from: "same but no aircon").acOn, false)
        XCTAssertEqual(TripQueryParser.hints(from: "now with cargo").load, .cargo)
        XCTAssertEqual(TripQueryParser.hints(from: "during rush hour").rushHour, true)
        XCTAssertFalse(TripQueryParser.hints(from: "hello there").hasAny)
    }

    func testIsFollowUpDetection() {
        XCTAssertTrue(FollowUp.isFollowUp("what about with heavy traffic",
                                          hints: TripHints(traffic: .heavy), vehicleChanged: false))
        XCTAssertTrue(FollowUp.isFollowUp("in my truck", hints: TripHints(), vehicleChanged: true))
        XCTAssertTrue(FollowUp.isFollowUp("same trip", hints: TripHints(), vehicleChanged: false))
        XCTAssertTrue(FollowUp.isFollowUp("what about now", hints: TripHints(), vehicleChanged: false))
        XCTAssertFalse(FollowUp.isFollowUp("hello there", hints: TripHints(), vehicleChanged: false))
    }

    func testMergeOverridesAndKeeps() {
        let prev = TripQuery(origin: "manila", destination: "batangas", vehicleName: "My Vios",
                             traffic: .heavy, acOn: true)
        let hints = TripHints(traffic: .standstill, load: .cargo)   // acOn/rush unspecified
        let merged = FollowUp.merge(previous: prev, hints: hints, vehicleName: nil)
        XCTAssertEqual(merged.origin, "manila")
        XCTAssertEqual(merged.destination, "batangas")
        XCTAssertEqual(merged.vehicleName, "My Vios")   // kept
        XCTAssertEqual(merged.traffic, .standstill)     // overridden
        XCTAssertEqual(merged.acOn, true)               // kept
        XCTAssertEqual(merged.load, .cargo)             // newly set
    }

    func testMergeChangesVehicle() {
        let prev = TripQuery(origin: "manila", destination: "cebu", vehicleName: nil)
        let merged = FollowUp.merge(previous: prev, hints: TripHints(), vehicleName: "My Truck")
        XCTAssertEqual(merged.vehicleName, "My Truck")
        XCTAssertEqual(merged.destination, "cebu")      // route unchanged
    }

    func testEndToEndFollowUp() {
        // A full trip, then a follow-up merges new conditions onto the same route.
        let q1 = TripQueryParser.parse("manila to batangas", vehicles: [])!
        XCTAssertNil(q1.traffic)

        let text = "same trip but heavy traffic and no AC"
        let hints = TripQueryParser.hints(from: text)
        XCTAssertTrue(FollowUp.isFollowUp(text, hints: hints, vehicleChanged: false))

        let merged = FollowUp.merge(previous: q1, hints: hints, vehicleName: nil)
        XCTAssertEqual(merged.origin, "manila")
        XCTAssertEqual(merged.destination, "batangas")
        XCTAssertEqual(merged.traffic, .heavy)
        XCTAssertEqual(merged.acOn, false)
    }

    func testEDSAFollowUpOnPreviousTrip() {
        let q1 = TripQueryParser.parse("makati to tagaytay", vehicles: [])!
        let text = "same trip but it's EDSA on a Friday"
        let hints = TripQueryParser.hints(from: text)
        let merged = FollowUp.merge(previous: q1, hints: hints, vehicleName: nil)
        XCTAssertEqual(merged.origin, "makati")
        XCTAssertEqual(merged.destination, "tagaytay")
        XCTAssertEqual(merged.traffic, .standstill)
    }
}
