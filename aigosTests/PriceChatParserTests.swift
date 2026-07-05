//
//  PriceChatParserTests.swift
//  aigosTests
//
//  Chat-based fuel-price editing: intent recognition (update / check / batch,
//  English + Tagalog), fuel-type aliases, price extraction + validation, the
//  batch-answer parser, the staleness reminder, and PriceService.update persistence.
//

import XCTest
import SwiftData
@testable import aigos

final class PriceChatParserTests: XCTestCase {

    // MARK: - Update recognition (English)

    func testUpdateEnglish() {
        XCTAssertEqual(PriceChatParser.parse("Update Premium 95 to 73"), .update(.premium95, 73))
        XCTAssertEqual(PriceChatParser.parse("Set diesel price to 69.10"), .update(.diesel, 69.10))
        XCTAssertEqual(PriceChatParser.parse("Change Unleaded 91 to 72 pesos"), .update(.unleaded91, 72))
        XCTAssertEqual(PriceChatParser.parse("Premium 97 is now 76"), .update(.premium97, 76))
    }

    // MARK: - Update recognition (Tagalog)

    func testUpdateTagalog() {
        XCTAssertEqual(PriceChatParser.parse("Palitan ang Premium 95 sa 73"), .update(.premium95, 73))
        XCTAssertEqual(PriceChatParser.parse("Bagong presyo ng diesel: 69.10"), .update(.diesel, 69.10))
    }

    // MARK: - Price validation

    func testPriceValidation() {
        XCTAssertTrue(PriceChatParser.isValidPrice(73))
        XCTAssertTrue(PriceChatParser.isValidPrice(40))
        XCTAssertTrue(PriceChatParser.isValidPrice(200))
        XCTAssertFalse(PriceChatParser.isValidPrice(0))
        XCTAssertFalse(PriceChatParser.isValidPrice(-5))
        XCTAssertFalse(PriceChatParser.isValidPrice(39.9))
        XCTAssertFalse(PriceChatParser.isValidPrice(500))

        // Out-of-range prices surface as .updateInvalidPrice, not .update.
        XCTAssertEqual(PriceChatParser.parse("set diesel to 500"), .updateInvalidPrice(.diesel, 500))
        XCTAssertEqual(PriceChatParser.parse("set diesel to 0"), .updateInvalidPrice(.diesel, 0))
    }

    // MARK: - Fuel-type aliases

    func testFuelTypeAliases() {
        XCTAssertEqual(PriceChatParser.fuelType(in: "u91"), .unleaded91)
        XCTAssertEqual(PriceChatParser.fuelType(in: "regular"), .unleaded91)
        XCTAssertEqual(PriceChatParser.fuelType(in: "p95"), .premium95)
        XCTAssertEqual(PriceChatParser.fuelType(in: "premium"), .premium95)
        XCTAssertEqual(PriceChatParser.fuelType(in: "p97"), .premium97)
        XCTAssertEqual(PriceChatParser.fuelType(in: "pd"), .premiumDiesel)
        XCTAssertEqual(PriceChatParser.fuelType(in: "diesel plus"), .premiumDiesel)
        XCTAssertEqual(PriceChatParser.fuelType(in: "e-gas"), .eGasoline)
        XCTAssertEqual(PriceChatParser.fuelType(in: "diesel"), .diesel)
        XCTAssertNil(PriceChatParser.fuelType(in: "manila to baguio"))
    }

    func testPriceExtractionExcludesGradeNumber() {
        // "95" is the grade, "73" is the price.
        XCTAssertEqual(PriceChatParser.priceValue(in: "premium 95 to 73", fuel: .premium95), 73)
        XCTAssertEqual(PriceChatParser.priceValue(in: "unleaded 91 to 72", fuel: .unleaded91), 72)
        XCTAssertEqual(PriceChatParser.priceValue(in: "diesel to 69.10", fuel: .diesel), 69.10)
    }

    // MARK: - Check + batch + edge cases

    func testCheckIntent() {
        for m in ["What is the current fuel price?", "Show current prices",
                  "Magkano ang gasolina today?", "Diesel price?", "Kanina magkano si Premium 95?"] {
            XCTAssertEqual(PriceChatParser.parse(m), .check, "failed for \(m)")
        }
    }

    func testBatchIntent() {
        XCTAssertEqual(PriceChatParser.parse("Update all prices"), .batch)
        XCTAssertEqual(PriceChatParser.parse("update all the prices please"), .batch)
    }

    func testEdgeCases() {
        XCTAssertEqual(PriceChatParser.parse("set the price to 73"), .updateUnknownFuel)  // no fuel
        XCTAssertEqual(PriceChatParser.parse("update premium 95"), .updateMissingPrice(.premium95))  // no price
    }

    func testNonPriceMessagesIgnored() {
        // Must NOT be stolen from the trip / vehicle / fuel-swap intents.
        XCTAssertEqual(PriceChatParser.parse("manila to baguio"), .none)
        XCTAssertEqual(PriceChatParser.parse("how can I save fuel?"), .none)
        XCTAssertEqual(PriceChatParser.parse("how about the diesel Innova?"), .none)
        XCTAssertEqual(PriceChatParser.parse("with premium instead"), .none)
    }

    // MARK: - Batch answers

    func testBatchAnswers() {
        XCTAssertEqual(PriceChatParser.batchAnswer("72.50"), .price(72.50))
        XCTAssertEqual(PriceChatParser.batchAnswer("skip"), .skip)
        XCTAssertEqual(PriceChatParser.batchAnswer("cancel"), .cancel)
        XCTAssertEqual(PriceChatParser.batchAnswer("500"), .invalid(500))
        XCTAssertEqual(PriceChatParser.batchAnswer("hello there"), .unclear)
    }

    // MARK: - Weekly staleness reminder

    func testStaleReminder() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        XCTAssertNotNil(PriceChatParser.staleReminder(lastUpdated: now.addingTimeInterval(-8 * 24 * 3600), now: now))
        XCTAssertNil(PriceChatParser.staleReminder(lastUpdated: now.addingTimeInterval(-3 * 24 * 3600), now: now))
        XCTAssertNil(PriceChatParser.staleReminder(lastUpdated: nil, now: now))
    }

    // MARK: - Persistence (marks user-edited, mirrors the Prices-tab pencil edit)

    @MainActor
    func testPriceServiceUpdatePersists() throws {
        let schema = Schema([
            VehicleProfile.self, DrivingProfile.self, TripRecord.self, SavedRoute.self,
            FuelPriceCache.self, PersonalPlace.self, TrackedTrip.self, FuelLog.self,
        ])
        let ctx = ModelContext(try ModelContainer(
            for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        ctx.insert(FuelPriceCache(fuelType: .diesel, pricePHP: 69.10, lastUpdated: Date(timeIntervalSince1970: 0), updatedBy: "developer"))
        try ctx.save()

        XCTAssertTrue(PriceService.update(.diesel, to: 70.5, in: ctx))
        let row = PriceService.cache(for: .diesel, in: ctx)
        XCTAssertEqual(row?.pricePHP, 70.5)
        XCTAssertEqual(row?.updatedBy, "user")   // → pencil icon on the Prices tab
        XCTAssertGreaterThan(row?.lastUpdated ?? .distantPast, Date(timeIntervalSince1970: 1))

        // Updating a fuel with no existing row creates one, user-edited.
        XCTAssertTrue(PriceService.update(.premium97, to: 77, in: ctx))
        XCTAssertEqual(PriceService.cache(for: .premium97, in: ctx)?.pricePHP, 77)
    }
}
