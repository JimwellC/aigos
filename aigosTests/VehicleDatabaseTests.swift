//
//  VehicleDatabaseTests.swift
//  aigosTests
//

import XCTest
@testable import aigos

final class VehicleDatabaseTests: XCTestCase {

    func testDatabaseLoads() {
        XCTAssertGreaterThan(VehicleDatabase.entries.count, 50, "VehicleDatabase.json should be bundled and loaded")
    }

    // 1. Exact model match
    func testExactMatch() {
        let vios = VehicleDatabase.find("What is the km/L of Vios?")
        XCTAssertEqual(vios?.model, "Vios")
        XCTAssertEqual(vios?.variant, "1.3L", "bare 'Vios' defaults to the first-listed variant")
        XCTAssertEqual(vios?.kmL, 14.7)

        let city = VehicleDatabase.find("My car is a Honda City 2022")
        XCTAssertEqual(city?.model, "City")
        XCTAssertEqual(city?.kmL, 16.5)
    }

    // 2. Fuzzy match with typos
    func testFuzzyMatch() {
        XCTAssertEqual(VehicleDatabase.find("my car is a vious")?.model, "Vios")
        XCTAssertEqual(VehicleDatabase.find("how about the innnova")?.model, "Innova")
        XCTAssertEqual(VehicleDatabase.find("fortunner efficiency")?.model, "Fortuner")
    }

    // 3. Variant selection (engine / fuel)
    func testVariantSelection() {
        XCTAssertEqual(VehicleDatabase.find("Vios 1.5 please")?.variant, "1.5L")
        XCTAssertEqual(VehicleDatabase.find("Vios 1.5 please")?.kmL, 13.5)
        XCTAssertEqual(VehicleDatabase.find("Innova diesel")?.fuel, "diesel")
        XCTAssertEqual(VehicleDatabase.find("Innova gas")?.variant, "gas")
        XCTAssertEqual(VehicleDatabase.find("Innova gas")?.kmL, 10.2)
    }

    // 4. Fuel-type recommendation
    func testFuelTypeQuestion() {
        let a = VehicleDatabase.answer(for: "What fuel type for Fortuner diesel?")
        XCTAssertNotNil(a)
        XCTAssertTrue(a!.text.contains("Diesel"), a!.text)
        XCTAssertTrue(a!.text.contains("Fortuner"), a!.text)
    }

    func testPremiumQuestion() {
        let a = VehicleDatabase.answer(for: "Is Premium 95 worth it for my car?")
        XCTAssertNotNil(a)
        XCTAssertTrue(a!.text.contains("Unleaded 91"), a!.text)
        XCTAssertNil(a!.efficiencyKmL)
    }

    // 5. Tier 2 fallback for unknown models
    func testTier2Fallback() {
        let a = VehicleDatabase.answer(for: "My car is a small sedan not in your list")
        XCTAssertNotNil(a)
        XCTAssertTrue(a!.text.lowercased().contains("don't have"), a!.text)
        XCTAssertTrue(a!.text.contains("14–17 km/L"), a!.text)   // sedan category range
    }

    func testTier2SuvDiesel() {
        let a = VehicleDatabase.answer(for: "I drive a diesel SUV that's not listed")
        XCTAssertNotNil(a)
        XCTAssertTrue(a!.text.contains("10–13 km/L"), a!.text)
    }

    // 6. Age-based efficiency degradation
    func testAgeDegradation() {
        let a = VehicleDatabase.answer(for: "My Vios is 10 years old, same efficiency?")
        XCTAssertNotNil(a)
        // 14.7 * 0.85 = 12.495 -> 12.5
        XCTAssertEqual(a!.efficiencyKmL, 12.5)
        XCTAssertTrue(a!.text.contains("12.5"), a!.text)
    }

    // Age uses the CalculationEngine band (8 yr → −15%), not a flat 0.85 blurb.
    func testAgeBandResponse() {
        let a = VehicleDatabase.answer(for: "My Vios is 8 years old")
        XCTAssertNotNil(a)
        XCTAssertTrue(a!.text.contains("15%"), a!.text)
        XCTAssertEqual(a!.efficiencyKmL, 12.5)   // 14.7 × 0.85 = 12.495 → 12.5
    }

    func testFoundVehicleOffersEfficiency() {
        let a = VehicleDatabase.answer(for: "how many km/L does a Wigo get")
        XCTAssertNotNil(a)
        XCTAssertEqual(a!.efficiencyKmL, 20.5)
        XCTAssertEqual(a!.vehicleType, .car)
        XCTAssertEqual(a!.fuelType, .unleaded91)
    }

    func testMotorcycleLookup() {
        let a = VehicleDatabase.answer(for: "I have a Mio, how much gas?")
        XCTAssertNotNil(a)
        XCTAssertEqual(a!.efficiencyKmL, 50)
        XCTAssertEqual(a!.vehicleType, .motorcycle)
    }

    // A plain trip question must NOT be treated as a vehicle query.
    func testTripQueryIgnored() {
        XCTAssertNil(VehicleDatabase.answer(for: "How much to drive Manila to Batangas?"))
    }

    func testHowToKnow() {
        let a = VehicleDatabase.answer(for: "how do I know my km/L?")
        XCTAssertNotNil(a)
        XCTAssertTrue(a!.text.lowercased().contains("odometer"), a!.text)
    }

    // 7. Newly added popular PH vehicles are present + findable.
    func testNewVehiclesPresent() {
        XCTAssertGreaterThanOrEqual(VehicleDatabase.entries.count, 95)
        XCTAssertEqual(VehicleDatabase.find("What's the km/L of a Land Cruiser?")?.model, "Land Cruiser")
        XCTAssertEqual(VehicleDatabase.find("Toyota Raize")?.kmL, 18.0)
        XCTAssertEqual(VehicleDatabase.find("Hyundai Creta")?.kmL, 16.0)
        XCTAssertEqual(VehicleDatabase.find("Ford Territory")?.model, "Territory")
        XCTAssertEqual(VehicleDatabase.find("Chery Tiggo 8")?.make, "Chery")
        XCTAssertEqual(VehicleDatabase.find("Maxus T60")?.fuel, "diesel")
    }

    // 8. "[model] is a SUV" → category clarification, not a location query.
    func testCategoryCorrectionLandCruiser() {
        let a = VehicleDatabase.answer(for: "Land cruiser is a SUV")
        XCTAssertNotNil(a)
        XCTAssertTrue(a!.text.contains("full-size SUV"), a!.text)
        XCTAssertTrue(a!.text.contains("8–11"), a!.text)          // diesel range
        XCTAssertEqual(a!.efficiencyKmL, 9.5)                     // offers to use it
        XCTAssertEqual(a!.fuelType, .diesel)
    }

    func testCategoryCorrectionGenericSUV() {
        let a = VehicleDatabase.answer(for: "The X-Trail is an SUV right?")
        XCTAssertNotNil(a)
        XCTAssertTrue(a!.text.contains("SUV"), a!.text)
        XCTAssertEqual(a!.efficiencyKmL, 13.0)
    }

    // 9. "What SUVs are fuel efficient?" → top ranking.
    func testBestSUVs() {
        let a = VehicleDatabase.answer(for: "What SUVs are fuel efficient?")
        XCTAssertNotNil(a)
        XCTAssertTrue(a!.text.contains("Raize"), a!.text)   // 18 km/L tops the SUVs
        XCTAssertTrue(a!.text.contains("Creta"), a!.text)   // 16 km/L
        XCTAssertTrue(a!.text.contains("km/L"), a!.text)
    }

    func testBestMotorcycles() {
        let a = VehicleDatabase.answer(for: "Cheapest to run motorcycle?")
        XCTAssertNotNil(a)
        XCTAssertTrue(a!.text.lowercased().contains("motorcycle"), a!.text)
        XCTAssertEqual(a!.text.components(separatedBy: "•").count, 4)   // 3 bullets
    }

    func testBestCarsForLongDrives() {
        let a = VehicleDatabase.answer(for: "Best car for long drives?")
        XCTAssertNotNil(a)
        XCTAssertTrue(a!.text.contains("km/L"), a!.text)
        XCTAssertEqual(a!.text.components(separatedBy: "•").count, 4)
    }
}
