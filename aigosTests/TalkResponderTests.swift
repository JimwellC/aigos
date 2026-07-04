//
//  TalkResponderTests.swift
//  aigosTests
//
//  Filipino normalization + small-talk / off-topic handling for Talk to aigos.
//

import XCTest
@testable import aigos

final class TalkResponderTests: XCTestCase {

    // MARK: - Filipino normalization

    func testFilipinoDistanceQuery() {
        let n = TalkNormalizer.normalize("Gaano kalayo ang Manila sa Batangas?")
        XCTAssertTrue(n.contains("manila to batangas"), n)
    }

    func testFilipinoGasCostQuery() {
        let n = TalkNormalizer.normalize("Magkano ang gas papuntang Baguio?")
        XCTAssertTrue(n.contains("how much"), n)
        XCTAssertTrue(n.contains("to baguio"), n)
    }

    func testFilipinoFuelQueryReachesVehicleBrain() {
        let n = TalkNormalizer.normalize("Anong gasolina para sa Vios?")
        XCTAssertTrue(n.contains("what fuel"), n)
        XCTAssertTrue(n.contains("vios"), n)

        let a = VehicleDatabase.answer(for: n)
        XCTAssertNotNil(a)
        XCTAssertTrue(a!.text.contains("Vios"), a!.text)
        XCTAssertTrue(a!.text.contains("Unleaded 91"), a!.text)
    }

    func testEnglishTextUntouched() {
        let input = "How much to Baguio"
        XCTAssertEqual(TalkNormalizer.normalize(input), input)
    }

    // MARK: - Small talk

    func testGreeting() {
        XCTAssertTrue(TalkSmallTalk.quickReply(for: "Hi")?.contains("Kamusta") ?? false)
        XCTAssertTrue(TalkSmallTalk.quickReply(for: "Kamusta")?.contains("aigos") ?? false)
        XCTAssertTrue(TalkSmallTalk.quickReply(for: "hello there")?.contains("Kamusta") ?? false)
    }

    func testThanks() {
        XCTAssertTrue(TalkSmallTalk.quickReply(for: "Salamat")?.contains("Walang anuman") ?? false)
        XCTAssertTrue(TalkSmallTalk.quickReply(for: "thank you")?.contains("Walang anuman") ?? false)
    }

    func testGoodbye() {
        XCTAssertTrue(TalkSmallTalk.quickReply(for: "Bye")?.contains("Paalam") ?? false)
        XCTAssertTrue(TalkSmallTalk.quickReply(for: "Paalam")?.contains("Paalam") ?? false)
    }

    func testConfusion() {
        XCTAssertTrue(TalkSmallTalk.quickReply(for: "What?")?.contains("Try asking") ?? false)
        XCTAssertTrue(TalkSmallTalk.quickReply(for: "I don't understand")?.contains("Try asking") ?? false)
    }

    func testSmallTalkIgnoresRealQueries() {
        XCTAssertNil(TalkSmallTalk.quickReply(for: "Manila to Batangas"))
        XCTAssertNil(TalkSmallTalk.quickReply(for: "What is the km/L of Vios?"))
        XCTAssertNil(TalkSmallTalk.quickReply(for: "How much to drive to Baguio"))
    }

    // MARK: - Off-topic vs. unresolved-trip fallback

    func testUnrelatedRedirect() {
        for q in ["What is the weather today?", "Who won the NBA?", "Tell me a joke", "What time is it?"] {
            XCTAssertEqual(TalkSmallTalk.fallback(for: q), TalkSmallTalk.unrelatedRedirect, q)
        }
        XCTAssertTrue(TalkSmallTalk.unrelatedRedirect.contains("fuel trip assistant"))
    }

    func testUnresolvedTripNudgesToCalculator() {
        XCTAssertTrue(TalkSmallTalk.fallback(for: "how much to Tokyo").contains("couldn't find that place"))
    }
}
