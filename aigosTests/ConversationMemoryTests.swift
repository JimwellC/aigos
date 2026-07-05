//
//  ConversationMemoryTests.swift
//  aigosTests
//
//  Conversation memory for "Talk to aigos": follow-up detection, condition
//  stacking, context preservation/reset/timeout, Tagalog follow-ups, per-person
//  and fuel-swap parsing, and the no-context edge case. All pure logic.
//

import XCTest
@testable import aigos

final class ConversationMemoryTests: XCTestCase {

    // MARK: - Follow-up detection accuracy

    func testConditionFollowUpsDetected() {
        if case .modifyConditions(let h) = FollowUp.classify("what about with heavy traffic?") {
            XCTAssertEqual(h.traffic, .heavy)
        } else { XCTFail("heavy traffic should be a condition follow-up") }

        if case .modifyConditions(let h) = FollowUp.classify("with AC off") {
            XCTAssertEqual(h.acOn, false)
        } else { XCTFail("AC off should be a condition follow-up") }

        if case .modifyConditions(let h) = FollowUp.classify("and 3 passengers?") {
            XCTAssertEqual(h.load, .moderate)
        } else { XCTFail("3 passengers should set load") }

        if case .modifyConditions(let h) = FollowUp.classify("with 5 people") {
            XCTAssertEqual(h.load, .full)   // 5 → full load
        } else { XCTFail("5 people should set full load") }
    }

    func testRoundTripDetected() {
        for m in ["round trip?", "Round trip", "return trip", "both ways", "balikan?"] {
            XCTAssertEqual(FollowUp.classify(m), .roundTrip, "failed for \(m)")
        }
    }

    func testPerPersonDetected() {
        XCTAssertEqual(FollowUp.classify("split between 4 people"), .perPerson(4))
        XCTAssertEqual(FollowUp.classify("per person"), .perPerson(nil))
        XCTAssertEqual(FollowUp.classify("magkano kada isa?"), .perPerson(nil))
        XCTAssertEqual(FollowUp.classify("split 3 ways"), .perPerson(3))
    }

    func testDistanceAndCheaperDetected() {
        for m in ["how far is it?", "how long will it take?", "what's the distance?"] {
            XCTAssertEqual(FollowUp.classify(m), .howFar, "failed for \(m)")
        }
        for m in ["how can I make it cheaper?", "cheapest option?", "mas mura ba?"] {
            XCTAssertEqual(FollowUp.classify(m), .cheaper, "failed for \(m)")
        }
    }

    func testFuelSwapDetected() {
        XCTAssertEqual(FollowUp.classify("if I use diesel?"), .swapFuel(.diesel))
        XCTAssertEqual(FollowUp.classify("with premium instead"), .swapFuel(.premium95))
        XCTAssertEqual(FollowUp.classify("what about premium 97"), .swapFuel(.premium97))
    }

    func testConfirmationResponses() {
        for m in ["yes", "oo", "sige", "use it", "opo"] {
            XCTAssertEqual(FollowUp.classify(m), .confirmYes, "failed for \(m)")
        }
        for m in ["no", "hindi", "ayaw ko"] {
            XCTAssertEqual(FollowUp.classify(m), .confirmNo, "failed for \(m)")
        }
        for m in ["ok", "okay", "got it"] {
            XCTAssertEqual(FollowUp.classify(m), .acknowledge, "failed for \(m)")
        }
    }

    func testResetDetected() {
        for m in ["new trip", "different question", "start over", "iba naman"] {
            XCTAssertEqual(FollowUp.classify(m), .reset, "failed for \(m)")
        }
    }

    // MARK: - Tagalog follow-ups

    func testTagalogFollowUps() {
        XCTAssertEqual(FollowUp.classify("balikan?"), .roundTrip)
        XCTAssertEqual(FollowUp.classify("paano kung diesel?"), .swapFuel(.diesel))
        XCTAssertEqual(FollowUp.classify("magkano kada isa?"), .perPerson(nil))
        XCTAssertEqual(FollowUp.classify("gaano kalayo?"), .howFar)
        XCTAssertEqual(FollowUp.classify("pwede bang mas mura?"), .cheaper)

        if case .modifyConditions(let h) = FollowUp.classify("pag walang aircon?") {
            XCTAssertEqual(h.acOn, false)
        } else { XCTFail("walang aircon should turn AC off") }

        // "Ilan kami, lima" → 5 people → full load.
        if case .modifyConditions(let h) = FollowUp.classify("ilan kami lima") {
            XCTAssertEqual(h.load, .full)
        } else { XCTFail("lima kami should set load") }
    }

    // MARK: - Head-count + fuel extraction

    func testHeadCount() {
        XCTAssertEqual(FollowUp.headCount(in: "split between 4 people"), 4)
        XCTAssertEqual(FollowUp.headCount(in: "for 3"), 3)
        XCTAssertEqual(FollowUp.headCount(in: "ilan kami lima"), 5)
        XCTAssertEqual(FollowUp.headCount(in: "apat kami"), 4)
        XCTAssertNil(FollowUp.headCount(in: "per person"))
    }

    func testFuelSwapRequiresFuelWord() {
        XCTAssertEqual(FollowUp.fuelSwap(in: "if I use diesel"), .diesel)
        XCTAssertEqual(FollowUp.fuelSwap(in: "with premium"), .premium95)
        XCTAssertNil(FollowUp.fuelSwap(in: "manila to baguio"))   // no fuel word
        XCTAssertNil(FollowUp.fuelSwap(in: "4 people"))           // bare number, no fuel word
    }

    // MARK: - Condition stacking (multiple follow-ups accumulate)

    func testConditionStacking() {
        let base = TripQuery(origin: "manila", destination: "baguio", vehicleName: nil,
                             traffic: nil, acOn: nil, rushHour: nil, load: nil)
        // First follow-up: AC off.
        let step1 = FollowUp.merge(previous: base, hints: TripHints(acOn: false), vehicleName: nil)
        XCTAssertEqual(step1.acOn, false)
        // Second follow-up: add 3 passengers — AC-off must persist.
        let step2 = FollowUp.merge(previous: step1, hints: TripHints(load: .moderate), vehicleName: nil)
        XCTAssertEqual(step2.acOn, false, "earlier condition must persist")
        XCTAssertEqual(step2.load, .moderate)
        XCTAssertEqual(step2.origin, "manila")
        XCTAssertEqual(step2.destination, "baguio")
    }

    // MARK: - Context preservation / reset / timeout / layers

    func testContextPreservationAndReset() {
        var c = TalkContext()
        XCTAssertFalse(c.hasTrip)
        c.tripQuery = TripQuery(origin: "manila", destination: "baguio", vehicleName: "Vios",
                                traffic: nil, acOn: nil, rushHour: nil, load: nil)
        c.lastCostPHP = 1200
        c.lastDistanceKm = 246
        XCTAssertTrue(c.hasTrip)
        XCTAssertEqual(c.routeLabel, "Manila → Baguio")

        c.reset()
        XCTAssertFalse(c.hasTrip)
        XCTAssertNil(c.lastCostPHP)
        XCTAssertNil(c.routeLabel)
    }

    func testMultipleContextLayers() {
        // A trip AND a vehicle can be remembered at the same time.
        var c = TalkContext()
        c.lastVehicleModel = "Vios"
        c.tripQuery = TripQuery(origin: "manila", destination: "baguio", vehicleName: nil,
                                traffic: nil, acOn: nil, rushHour: nil, load: nil)
        XCTAssertEqual(c.lastVehicleModel, "Vios")
        XCTAssertTrue(c.hasTrip)
    }

    func testContextTimeout() {
        var c = TalkContext()
        let now = Date(timeIntervalSince1970: 1_000_000)
        c.updatedAt = now
        XCTAssertFalse(c.isStale(now: now.addingTimeInterval(120)))   // 2 min → fresh
        XCTAssertTrue(c.isStale(now: now.addingTimeInterval(600)))    // 10 min → stale
        // No timestamp → never stale.
        var fresh = TalkContext()
        fresh.updatedAt = nil
        XCTAssertFalse(fresh.isStale(now: now.addingTimeInterval(9_999)))
    }

    // MARK: - Edge case: follow-up with no context / plain queries

    func testPlainQueryIsNotAFollowUp() {
        // A message that fully names a trip or vehicle isn't a follow-up marker.
        XCTAssertEqual(FollowUp.classify("manila to baguio"), .none)
        XCTAssertEqual(FollowUp.classify("what's the km/L of a Vios?"), .none)
        XCTAssertEqual(FollowUp.classify("how's my driving?"), .none)
    }

    func testRepeatLastMarker() {
        XCTAssertEqual(FollowUp.classify("the same"), .repeatLast)
        XCTAssertEqual(FollowUp.classify("what about"), .repeatLast)
    }
}
