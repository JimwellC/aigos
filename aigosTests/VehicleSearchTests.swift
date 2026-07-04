//
//  VehicleSearchTests.swift
//  aigosTests
//
//  Database-first vehicle search: prefix/nickname matching, fuzzy typo tolerance,
//  category search, the not-found fallback path, and that a selected result
//  carries every field the Add-Vehicle form auto-fills.
//

import XCTest
@testable import aigos

final class VehicleSearchTests: XCTestCase {

    // MARK: - Search finds all common models

    func testFindsCommonModels() {
        for model in ["Vios", "Innova", "Fortuner", "Wigo", "Montero", "Ranger",
                      "mu-X", "Xpander", "Civic", "CR-V", "NMAX", "Click"] {
            let hits = VehicleDatabase.search(model)
            XCTAssertFalse(hits.isEmpty, "search should find \(model)")
            XCTAssertTrue(hits.contains { $0.displayName.lowercased().contains(model.lowercased().replacingOccurrences(of: "-", with: "")) || $0.model.lowercased().contains(model.lowercased()) },
                          "results for \(model) should include it")
        }
    }

    func testPrefixSearch() {
        let hits = VehicleDatabase.search("vio")
        XCTAssertTrue(hits.contains { $0.model == "Vios" })
    }

    // MARK: - Fuzzy typos

    func testFuzzyTyposResolve() {
        XCTAssertTrue(VehicleDatabase.search("toyta").contains { $0.make == "Toyota" }, "toyta → Toyota")
        XCTAssertTrue(VehicleDatabase.search("fortner").contains { $0.model == "Fortuner" }, "fortner → Fortuner")
        XCTAssertTrue(VehicleDatabase.search("innowa").contains { $0.model == "Innova" }, "innowa → Innova")
    }

    // MARK: - Nicknames / joined forms

    func testNicknameAndJoinedForms() {
        XCTAssertTrue(VehicleDatabase.search("fort").contains { $0.model == "Fortuner" }, "fort → Fortuner")
        XCTAssertTrue(VehicleDatabase.search("mu").contains { $0.model == "mu-X" }, "mu → mu-X")
        XCTAssertTrue(VehicleDatabase.search("crv").contains { $0.model == "CR-V" }, "crv → CR-V")
    }

    // MARK: - Category search

    func testCategorySearch() {
        let suvs = VehicleDatabase.search("SUV")
        XCTAssertFalse(suvs.isEmpty)
        XCTAssertTrue(suvs.allSatisfy { $0.category.contains("suv") || $0.category.contains("crossover") })

        let sedans = VehicleDatabase.search("sedan")
        XCTAssertFalse(sedans.isEmpty)
        XCTAssertTrue(sedans.allSatisfy { $0.category.contains("sedan") })

        let motos = VehicleDatabase.search("motorcycle")
        XCTAssertFalse(motos.isEmpty)
        XCTAssertTrue(motos.allSatisfy { $0.vehicleType == .motorcycle })
    }

    // MARK: - Fallback path (nothing found → manual entry)

    func testNoMatchReturnsEmptyForFallback() {
        XCTAssertTrue(VehicleDatabase.search("zzqwertynotavehicle").isEmpty)
        XCTAssertTrue(VehicleDatabase.search("").isEmpty)
    }

    // MARK: - Auto-fill populates all fields

    func testSelectionCarriesAllFields() {
        let vios13 = VehicleDatabase.search("Vios").first { $0.variant == "1.3L" }
        XCTAssertNotNil(vios13)
        XCTAssertEqual(vios13?.kmL, 14.7)
        XCTAssertEqual(vios13?.fuelType, .unleaded91)
        XCTAssertEqual(vios13?.vehicleType, .car)
        XCTAssertEqual(vios13?.tankCapacityL, 42)

        // Both engine variants are individually selectable.
        let variants = VehicleDatabase.search("Vios").filter { $0.model == "Vios" }.compactMap(\.variant)
        XCTAssertTrue(variants.contains("1.3L"))
        XCTAssertTrue(variants.contains("1.5L"))
    }
}
