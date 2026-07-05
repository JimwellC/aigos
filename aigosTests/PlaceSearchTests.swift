//
//  PlaceSearchTests.swift
//  aigosTests
//
//  Autocomplete suggestions + the exact-match validation that rejects random
//  text like "J".
//

import XCTest
@testable import aigos

final class PlaceSearchTests: XCTestCase {

    private func titles(_ q: String, _ personal: [PersonalPlace] = []) -> [String] {
        PlaceSearch.suggestions(for: q, personalPlaces: personal).map(\.title)
    }

    // MARK: - Suggestions

    func testPartialMatch() {
        let t = titles("man")
        XCTAssertTrue(t.contains("Manila"))
        XCTAssertTrue(t.contains("Mandaluyong"))
        XCTAssertLessThanOrEqual(t.count, 5)
    }

    func testAliasMatch() {
        XCTAssertEqual(PlaceSearch.suggestions(for: "BGC", personalPlaces: []).first?.title,
                       "Bonifacio Global City")
    }

    func testCaseInsensitiveMatching() {
        for q in ["bgc", "BGC", "Bgc"] {
            XCTAssertEqual(PlaceSearch.suggestions(for: q, personalPlaces: []).first?.title,
                           "Bonifacio Global City", "failed for \(q)")
        }
    }

    func testEmptyAndWhitespaceRejected() {
        XCTAssertTrue(PlaceSearch.suggestions(for: "", personalPlaces: []).isEmpty)
        XCTAssertTrue(PlaceSearch.suggestions(for: "   ", personalPlaces: []).isEmpty)
        XCTAssertTrue(PlaceSearch.suggestions(for: "\n\t", personalPlaces: []).isEmpty)
    }

    func testNonsenseYieldsNothing() {
        XCTAssertTrue(PlaceSearch.suggestions(for: "zzqq", personalPlaces: []).isEmpty)
    }

    func testMaxFiveResults() {
        XCTAssertLessThanOrEqual(PlaceSearch.suggestions(for: "a", personalPlaces: []).count, 5)
    }

    func testPrefixRankedFirst() {
        XCTAssertEqual(titles("batangas").first, "Batangas City")
    }

    func testPersonalPlacesFirst() {
        let personal = [PersonalPlace(name: "Manila Pad", gazetteerKey: "makati")]
        let s = PlaceSearch.suggestions(for: "manila", personalPlaces: personal)
        XCTAssertEqual(s.first?.title, "Manila Pad")
        XCTAssertTrue(s.first?.isPersonal ?? false)
        XCTAssertTrue(s.contains { $0.title == "Manila" && !$0.isPersonal })
    }

    func testUnconfiguredPersonalPlaceNotSuggested() {
        let personal = [PersonalPlace(name: "School", gazetteerKey: "")]   // not mapped
        XCTAssertFalse(PlaceSearch.suggestions(for: "school", personalPlaces: personal)
            .contains { $0.isPersonal })
    }

    // MARK: - Validation (exact-key)

    func testExactKeyRejectsRandomText() {
        XCTAssertNil(PlaceSearch.exactKey("J", personalPlaces: []))
        XCTAssertNil(PlaceSearch.exactKey("K", personalPlaces: []))
        XCTAssertNil(PlaceSearch.exactKey("man", personalPlaces: []))     // partial
        XCTAssertNil(PlaceSearch.exactKey("   ", personalPlaces: []))
    }

    func testExactKeyAcceptsRealPlaces() {
        XCTAssertEqual(PlaceSearch.exactKey("Manila", personalPlaces: []), "manila")
        XCTAssertEqual(PlaceSearch.exactKey("bgc", personalPlaces: []), "bgc")
        XCTAssertEqual(PlaceSearch.exactKey("Cagayan de Oro", personalPlaces: []), "cagayan de oro")
    }

    func testExactKeyPersonalName() {
        let personal = [PersonalPlace(name: "Home", gazetteerKey: "makati")]
        XCTAssertEqual(PlaceSearch.exactKey("home", personalPlaces: personal), "Home")
    }

    // MARK: - Gazetteer expansion sanity

    func testAliasesResolve() {
        for alias in ["bgc", "edsa", "nlex", "slex", "c5", "qc", "cdo", "gensan"] {
            XCTAssertTrue(GazetteerRouteResolver.isPlace(alias), "\(alias) should resolve")
        }
    }

    func testEntriesHaveSubtitles() {
        XCTAssertGreaterThan(GazetteerRouteResolver.entries.count, 150)
        XCTAssertTrue(GazetteerRouteResolver.entries.allSatisfy { !$0.subtitle.isEmpty && !$0.title.isEmpty })
    }

    // MARK: - F-3: a tapped suggestion always resolves to its exact coordinate

    /// Each gazetteer suggestion embeds the entry's precise coordinate (like a map
    /// pin), so selecting it can never re-resolve to a different same-named place.
    func testSuggestionKeyResolvesToExactCoordinate() {
        for q in ["Manila", "Batangas City", "Cebu City", "Baguio", "Davao"] {
            guard let s = PlaceSearch.suggestions(for: q, personalPlaces: [])
                .first(where: { !$0.isPersonal }) else {
                XCTFail("no gazetteer suggestion for \(q)"); continue
            }
            XCTAssertTrue(s.resolveKey.hasPrefix("@pin:"), "\(q): key should embed a coordinate")
            guard let resolved = PlaceResolver.point(for: s.resolveKey, personalPlaces: []),
                  let expected = GazetteerRouteResolver.entry(for: s.title)?.point else {
                XCTFail("\(q): key did not resolve"); continue
            }
            XCTAssertEqual(resolved.lat, expected.lat, accuracy: 0.0001, "\(q) lat")
            XCTAssertEqual(resolved.lon, expected.lon, accuracy: 0.0001, "\(q) lon")
        }
    }

    /// F-9 regression: coordinates removed for being wrong are gone; nearby valid
    /// places still resolve.
    func testRemovedWrongLandmarksAreGone() {
        XCTAssertNil(GazetteerRouteResolver.index["lto east ave"])
        XCTAssertNil(GazetteerRouteResolver.index["nueva ecija capitol"])
        XCTAssertTrue(GazetteerRouteResolver.isPlace("palayan"))   // still covered nearby
        XCTAssertTrue(GazetteerRouteResolver.isPlace("dfa"))       // verified entry kept
    }
}
