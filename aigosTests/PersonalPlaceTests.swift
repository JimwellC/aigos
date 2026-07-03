//
//  PersonalPlaceTests.swift
//  aigosTests
//
//  Personal-place shortcuts resolve before the gazetteer, case-insensitively —
//  this is what makes "home to office" work.
//

import XCTest
@testable import aigos

final class PersonalPlaceTests: XCTestCase {

    private func places() -> [PersonalPlace] {
        [
            PersonalPlace(name: "Home", gazetteerKey: "makati"),
            PersonalPlace(name: "Office", gazetteerKey: "pasig"),
            PersonalPlace(name: "School", gazetteerKey: ""),   // not configured
        ]
    }

    func testAliasResolutionIsCaseInsensitive() {
        let makati = GazetteerRouteResolver.lookup("makati")
        XCTAssertNotNil(makati)
        for query in ["home", "Home", "HOME", "  home  "] {
            XCTAssertEqual(PlaceResolver.point(for: query, personalPlaces: places()), makati,
                           "\(query) should resolve to Home → Makati")
        }
    }

    func testGazetteerFallbackStillWorks() {
        XCTAssertEqual(PlaceResolver.point(for: "manila", personalPlaces: places()),
                       GazetteerRouteResolver.lookup("manila"))
        XCTAssertNil(PlaceResolver.point(for: "narnia", personalPlaces: places()))
    }

    func testUnconfiguredAliasDoesNotResolve() {
        // "School" has no mapping and isn't a real place → nil.
        XCTAssertNil(PlaceResolver.point(for: "school", personalPlaces: places()))
    }

    func testRouteResolvesBothAliases() {
        let route = PlaceResolver.route(from: "home", to: "office", personalPlaces: places())
        XCTAssertNotNil(route)
        XCTAssertGreaterThan(route!.distanceKm, 0)
        // Identical to Makati → Pasig computed directly.
        let direct = GazetteerRouteResolver().route(from: "makati", to: "pasig")
        XCTAssertEqual(route!.distanceKm, direct!.distanceKm, accuracy: 0.001)
    }

    func testParserRecognizesAliases() {
        let q = TripQueryParser.parse("home to office", vehicles: [], personalPlaces: places())
        XCTAssertEqual(q?.origin, "home")
        XCTAssertEqual(q?.destination, "office")
    }

    func testParserAliasesAreCaseInsensitive() {
        let q = TripQueryParser.parse("How much from HOME to Office?", vehicles: [], personalPlaces: places())
        XCTAssertEqual(q?.origin, "home")
        XCTAssertEqual(q?.destination, "office")
    }

    func testParserMixesAliasAndGazetteer() {
        // "home to cebu" — personal origin, gazetteer destination.
        let q = TripQueryParser.parse("home to cebu", vehicles: [], personalPlaces: places())
        XCTAssertEqual(q?.origin, "home")
        XCTAssertEqual(q?.destination, "cebu")
    }

    func testParserIgnoresUnconfiguredAlias() {
        // School isn't mapped, so the trip can't fully resolve.
        XCTAssertNil(TripQueryParser.parse("home to school", vehicles: [], personalPlaces: places()))
    }

    func testParserWithoutPersonalPlacesUnchanged() {
        let q = TripQueryParser.parse("manila to cebu", vehicles: [])
        XCTAssertEqual(q?.origin, "manila")
        XCTAssertEqual(q?.destination, "cebu")
    }

    func testIsConfiguredFlag() {
        XCTAssertTrue(PersonalPlace(name: "Home", gazetteerKey: "makati").isConfigured)
        XCTAssertFalse(PersonalPlace(name: "Home").isConfigured)
    }
}
