//
//  MultiModalTripTests.swift
//  aigosTests
//
//  Cross-island (sea/air) trip detection, the ferry/flight route databases, and
//  that specific places (malls, hospitals, universities, airports/ports) resolve.
//

import XCTest
@testable import aigos

final class MultiModalTripTests: XCTestCase {

    // MARK: - Island mapping

    func testIslandMapping() {
        XCTAssertEqual(IslandResolver.island(forPlace: "Manila"), "Luzon")
        XCTAssertEqual(IslandResolver.island(forPlace: "Baguio"), "Luzon")
        XCTAssertEqual(IslandResolver.island(forPlace: "Angeles"), "Luzon")
        XCTAssertEqual(IslandResolver.island(forPlace: "Cebu"), "Cebu")
        XCTAssertEqual(IslandResolver.island(forPlace: "Davao"), "Mindanao")
        XCTAssertEqual(IslandResolver.island(forPlace: "Iloilo"), "Panay")
        XCTAssertEqual(IslandResolver.island(forPlace: "Bacolod"), "Negros")
        XCTAssertEqual(IslandResolver.island(forPlace: "Calapan"), "Mindoro")
        XCTAssertEqual(IslandResolver.island(forPlace: "Puerto Princesa"), "Palawan")
    }

    func testBoracayOverridesToSeparateIsland() {
        XCTAssertEqual(IslandResolver.island(forPlace: "Boracay"), "Boracay")
    }

    // MARK: - Same-island vs cross-island

    func testSameIslandIsNotCross() {
        XCTAssertFalse(IslandResolver.isCrossIsland("Manila", "Baguio"))   // both Luzon
        XCTAssertFalse(IslandResolver.isCrossIsland("Cebu City", "Cebu"))  // same island
        XCTAssertFalse(IslandResolver.isCrossIsland("Manila", "Batangas"))
    }

    func testCrossIslandDetected() {
        XCTAssertTrue(IslandResolver.isCrossIsland("Angeles", "Davao"))    // the reported bug
        XCTAssertTrue(IslandResolver.isCrossIsland("Manila", "Cebu"))
        XCTAssertTrue(IslandResolver.isCrossIsland("Iloilo", "Bacolod"))   // Panay ↔ Negros ferry
        XCTAssertTrue(IslandResolver.isCrossIsland("Manila", "Puerto Princesa"))
    }

    func testUnknownPlaceIsNotBlocked() {
        // Unresolvable places must NOT be treated as cross-island (no false block).
        XCTAssertFalse(IslandResolver.isCrossIsland("Manila", "zzznowhere"))
    }

    func testHubs() {
        XCTAssertEqual(IslandResolver.hub(for: "Luzon"), "Manila")
        XCTAssertEqual(IslandResolver.hub(for: "Cebu"), "Cebu City")
        XCTAssertEqual(IslandResolver.hub(for: "Mindanao"), "Davao City")
    }

    // MARK: - Flight database

    func testFlightLookup() {
        let f = TravelRoutes.flight(from: "Manila", to: "Cebu City")
        XCTAssertNotNil(f)
        XCTAssertEqual(f?.minPHP, 1500)
        XCTAssertEqual(f?.maxPHP, 8000)
        XCTAssertEqual(f?.hours, 1.5)
        // Reverse direction resolves to the same route.
        XCTAssertEqual(TravelRoutes.flight(from: "Cebu City", to: "Manila"), f)
        XCTAssertNil(TravelRoutes.flight(from: "Manila", to: "Nowhere City"))
    }

    // MARK: - Ferry database

    func testFerryLookup() {
        let iloiloBacolod = TravelRoutes.ferry(from: "Iloilo", to: "Bacolod")
        XCTAssertNotNil(iloiloBacolod)
        XCTAssertEqual(iloiloBacolod?.hours, 1)

        let roro = TravelRoutes.ferry(from: "Matnog", to: "Allen")
        XCTAssertEqual(roro?.withCarPHP, 1500)   // ro-ro with a car

        XCTAssertNotNil(TravelRoutes.ferry(from: "Batangas", to: "Calapan"))
    }

    // MARK: - Land portion still calculable within an island

    func testLandPortionDistanceIsReasonable() {
        let route = PlaceResolver.route(from: "Angeles", to: "Manila", personalPlaces: [])
        XCTAssertNotNil(route)
        // Angeles → Manila is roughly 80–100 km by road.
        XCTAssertGreaterThan(route!.distanceKm, 60)
        XCTAssertLessThan(route!.distanceKm, 130)
    }

    // MARK: - Specific-place recognition (malls, hospitals, universities, hubs)

    func testSpecificPlacesResolve() {
        for q in ["SM Megamall", "moa", "St. Luke's BGC", "Maginhawa", "Intramuros",
                  "Ateneo de Manila", "NAIA", "Caticlan", "Mactan-Cebu International Airport",
                  "Enchanted Kingdom", "PGH", "Glorietta"] {
            XCTAssertNotNil(GazetteerRouteResolver.entry(for: q), "should resolve place: \(q)")
        }
    }
}
