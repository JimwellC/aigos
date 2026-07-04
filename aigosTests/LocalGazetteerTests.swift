//
//  LocalGazetteerTests.swift
//  aigosTests
//
//  Offline coverage for the developer's home region (Central/Northern Luzon).
//  Coordinates were verified via MKLocalSearch, so these resolve AND sit on the
//  correct landmass (Luzon), keeping distance estimates sane offline.
//

import XCTest
@testable import aigos

final class LocalGazetteerTests: XCTestCase {

    func testLocalPlacesResolve() {
        for q in ["SM Pampanga", "SM Clark", "Marquee Mall", "Nepo Mall", "Porac",
                  "Floridablanca", "Dau Bus Terminal", "Holy Angel University",
                  "SM Marilao", "Barasoain Church", "SM Tarlac", "SM Cabanatuan",
                  "Subic Bay Freeport Zone", "SM City Bataan", "SM Dagupan",
                  "CSI City Mall La Union", "SM Baguio", "Burnham Park", "Camp John Hay"] {
            XCTAssertNotNil(GazetteerRouteResolver.entry(for: q), "should resolve: \(q)")
        }
    }

    func testLocalAliasesResolve() {
        let alias: [(String, String)] = [
            ("dau", "Dau Bus Terminal"), ("marquee", "Marquee Mall"), ("nepo", "Nepo Mall"),
            ("fields", "Fields Avenue"), ("hau", "Holy Angel University"),
            ("auf", "Angeles University Foundation"), ("pma", "Philippine Military Academy"),
            ("sbma", "Subic Bay Freeport Zone"), ("burnham", "Burnham Park"),
        ]
        for (a, title) in alias {
            XCTAssertEqual(GazetteerRouteResolver.entry(for: a)?.title, title, "alias \(a) → \(title)")
        }
    }

    func testLocalPlacesAreLuzon() {
        // A trip within the home region must NOT be flagged as cross-island.
        XCTAssertFalse(IslandResolver.isCrossIsland("Porac", "SM Pampanga"))
        XCTAssertFalse(IslandResolver.isCrossIsland("SM Baguio", "Marquee Mall"))
        XCTAssertEqual(IslandResolver.island(forPlace: "SM Clark"), "Luzon")
    }

    func testLocalCoordinatesInRegion() {
        // Every added Pampanga place sits in the Central Luzon bounding box.
        let pampanga = GazetteerRouteResolver.entries.filter { $0.subtitle == "Pampanga" }
        XCTAssertGreaterThan(pampanga.count, 10)
        for e in pampanga {
            XCTAssert((14.8...15.4).contains(e.point.lat), "\(e.title) lat \(e.point.lat)")
            XCTAssert((120.4...120.9).contains(e.point.lon), "\(e.title) lon \(e.point.lon)")
        }
    }
}
