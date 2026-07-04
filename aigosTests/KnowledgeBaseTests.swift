//
//  KnowledgeBaseTests.swift
//  aigosTests
//
//  Offline knowledge layer: efficiency-modifier + route data files, education,
//  troubleshooting, culture, cost, CO2, timing, and Tagalog variants.
//

import XCTest
@testable import aigos

final class KnowledgeBaseTests: XCTestCase {

    private let vios = KnowledgeBase.Vehicle(name: "My Vios", efficiencyKmL: 14.7,
                                             fuelType: .unleaded91, pricePerLitre: 65.0)

    // MARK: - Data files

    func testDataFilesLoad() {
        XCTAssertNotNil(KnowledgeBase.modifiers, "RealWorldEfficiencyDatabase.json should bundle + load")
        XCTAssertGreaterThanOrEqual(KnowledgeBase.routes.count, 8, "RouteConditionsDatabase.json should bundle + load")
    }

    func testAgeFactorBands() {
        guard let m = KnowledgeBase.modifiers else { return XCTFail("no modifiers") }
        XCTAssertEqual(m.ageFactor(forYears: 1).factor, 1.00)
        XCTAssertEqual(m.ageFactor(forYears: 4).factor, 0.92)
        XCTAssertEqual(m.ageFactor(forYears: 8).factor, 0.85)
        XCTAssertEqual(m.ageFactor(forYears: 13).factor, 0.75)
        XCTAssertEqual(m.ageFactor(forYears: 25).factor, 0.65)
    }

    func testModifierFactors() {
        guard let m = KnowledgeBase.modifiers else { return XCTFail("no modifiers") }
        XCTAssertEqual(m.driving["aggressive"]?.factor, 0.75)
        XCTAssertEqual(m.weather["heavyRain"]?.factor, 0.92)
        XCTAssertEqual(m.elevation["mountainClimb"]?.factor, 0.75)
        XCTAssertEqual(m.cargo["roofRack"]?.factor, 0.88)
    }

    // MARK: - Education

    func testImproveEconomy() {
        let a = KnowledgeBase.answer(for: "How can I improve my fuel economy?", vehicle: vios)
        XCTAssertNotNil(a)
        XCTAssertTrue(a!.contains("80–90"), a!)
        XCTAssertTrue(a!.contains("PMS"), a!)
        XCTAssertTrue(a!.contains("My Vios"), a!)   // personalised
    }

    func testRefuel() {
        XCTAssertTrue(KnowledgeBase.answer(for: "When should I refuel?")?.contains("1/4") ?? false)
    }

    func testWastage() {
        XCTAssertTrue(KnowledgeBase.answer(for: "What causes fuel wastage?")?.lowercased().contains("idling") ?? false)
    }

    func testDieselVsGas() {
        let a = KnowledgeBase.answer(for: "Diesel vs gasoline — which is better?")
        XCTAssertNotNil(a)
        XCTAssertTrue(a!.contains("DIESEL"), a!)
        XCTAssertTrue(a!.contains("GASOLINE"), a!)
    }

    // MARK: - Troubleshooting

    func testUsesMoreGas() {
        let a = KnowledgeBase.answer(for: "My car uses more gas lately, why?")
        XCTAssertNotNil(a)
        XCTAssertTrue(a!.lowercased().contains("air filter"), a!)
    }

    func testNeedsPMS() {
        let a = KnowledgeBase.answer(for: "My car needs PMS")
        XCTAssertNotNil(a)
        XCTAssertTrue(a!.contains("15%"), a!)
    }

    func testPremiumForVios() {
        let a = KnowledgeBase.answer(for: "Should I use Premium 95 in my Vios?")
        XCTAssertNotNil(a)
        XCTAssertTrue(a!.contains("Unleaded 91"), a!)
        XCTAssertTrue(a!.contains("Vios"), a!)
    }

    // MARK: - Culture

    func testJeepney() {
        XCTAssertTrue(KnowledgeBase.answer(for: "What is jeepney fuel efficiency?")?.contains("5–7") ?? false)
    }

    func testTricycle() {
        XCTAssertTrue(KnowledgeBase.answer(for: "How much does tricycle fuel cost?")?.contains("25–35") ?? false)
    }

    func testFamilyCar() {
        XCTAssertTrue(KnowledgeBase.answer(for: "What is a good family car for PH?")?.contains("Avanza") ?? false)
    }

    func testTyphoon() {
        XCTAssertTrue(KnowledgeBase.answer(for: "Should I drive during typhoon season?")?.contains("half full") ?? false)
    }

    // MARK: - Routes / cost / timing / CO2

    func testRouteFacts() {
        // "route" (not "toll") → the route-facts card with distance + via.
        let a = KnowledgeBase.answer(for: "Route info for Manila to Baguio")
        XCTAssertNotNil(a)
        XCTAssertTrue(a!.contains("TPLEX"), a!)
        XCTAssertTrue(a!.contains("246"), a!)
    }

    func testBestTime() {
        let a = KnowledgeBase.answer(for: "What time is best to drive to Baguio?")
        XCTAssertNotNil(a)
        XCTAssertTrue(a!.contains("Sat"), a!)
        XCTAssertTrue(a!.contains("Baguio"), a!)
    }

    func testDriveVsBus() {
        let a = KnowledgeBase.answer(for: "Is it cheaper to drive or take a bus to Baguio?", vehicle: vios)
        XCTAssertNotNil(a)
        XCTAssertTrue(a!.contains("DRIVE"), a!)
        XCTAssertTrue(a!.contains("BUS"), a!)
        XCTAssertTrue(a!.contains("PHP"), a!)
    }

    func testCO2() {
        let a = KnowledgeBase.answer(for: "How much CO2 does my trip produce?", vehicle: vios)
        XCTAssertNotNil(a)
        XCTAssertTrue(a!.contains("2.31"), a!)
    }

    // MARK: - Tagalog variants

    func testTagalogImproveEconomy() {
        XCTAssertTrue(KnowledgeBase.answer(for: "Paano makatipid sa gasolina?")?.contains("PMS") ?? false)
    }

    func testTagalogDieselVsGas() {
        XCTAssertTrue(KnowledgeBase.answer(for: "Diesel o gasolina?")?.contains("DIESEL") ?? false)
    }

    // MARK: - Toll / RFID / coding / emergency

    func testTollDatabaseLoads() {
        XCTAssertNotNil(KnowledgeBase.tolls)
        XCTAssertGreaterThanOrEqual(KnowledgeBase.tolls?.fullRoutes.count ?? 0, 10)
    }

    func testTollLookup() {
        let a = KnowledgeBase.answer(for: "How much is the toll to Baguio?")
        XCTAssertNotNil(a)
        XCTAssertTrue(a!.contains("PHP 450"), a!)
        XCTAssertTrue(a!.contains("Class 1"), a!)          // mandatory class note
        XCTAssertTrue(a!.contains("expressway.ph"), a!)    // disclaimer
    }

    func testTollGenericFallback() {
        let a = KnowledgeBase.answer(for: "What are the expressway toll fees?")
        XCTAssertNotNil(a)
        XCTAssertTrue(a!.contains("Class 1"), a!)
    }

    func testRFIDLoad() {
        let a = KnowledgeBase.answer(for: "How do I load my Easytrip?")
        XCTAssertNotNil(a)
        XCTAssertTrue(a!.contains("GCash"), a!)
    }

    func testWhichRFID() {
        let a = KnowledgeBase.answer(for: "Which RFID do I need?")
        XCTAssertNotNil(a)
        XCTAssertTrue(a!.lowercased().contains("interoperable"), a!)
    }

    func testNumberCoding() {
        let a = KnowledgeBase.answer(for: "What is number coding?")
        XCTAssertNotNil(a)
        XCTAssertTrue(a!.contains("Mon"), a!)
        XCTAssertTrue(a!.contains("1 & 2"), a!)
    }

    func testEmergency() {
        let a = KnowledgeBase.answer(for: "What if I break down on the expressway?")
        XCTAssertNotNil(a)
        XCTAssertTrue(a!.lowercased().contains("hazard"), a!)
        XCTAssertTrue(a!.contains("136"), a!)
    }

    // MARK: - Must not swallow real trip / vehicle queries

    func testIgnoresTripAndVehicleQueries() {
        XCTAssertNil(KnowledgeBase.answer(for: "Manila to Batangas"))
        XCTAssertNil(KnowledgeBase.answer(for: "What's the km/L of a Vios?"))
        XCTAssertNil(KnowledgeBase.answer(for: "How much to drive to Baguio?"))
    }
}
