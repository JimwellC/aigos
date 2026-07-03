//
//  RouteResolverTests.swift
//  aigosTests
//
//  Offline gazetteer distance prototype (Section 7). Distances are approximate
//  (haversine × winding factor), so assertions use generous tolerances.
//

import XCTest
@testable import aigos

final class RouteResolverTests: XCTestCase {

    private let resolver = GazetteerRouteResolver()

    func testKnownPlacesResolve() {
        XCTAssertNotNil(GazetteerRouteResolver.lookup("manila"))
        XCTAssertNotNil(GazetteerRouteResolver.lookup("Batangas"))   // case-insensitive
        XCTAssertTrue(GazetteerRouteResolver.isPlace("cebu"))
    }

    func testProvinceAliases() {
        XCTAssertTrue(GazetteerRouteResolver.isPlace("pampanga"))
        XCTAssertTrue(GazetteerRouteResolver.isPlace("bulacan"))
        XCTAssertTrue(GazetteerRouteResolver.isPlace("laguna"))
    }

    func testIsPlaceKeyDistinguishesWholeWords() {
        XCTAssertTrue(GazetteerRouteResolver.isPlaceKey("makati"))
        XCTAssertTrue(GazetteerRouteResolver.isPlaceKey("pampanga"))
        XCTAssertFalse(GazetteerRouteResolver.isPlaceKey("cagayan"))  // part of "cagayan de oro"
        XCTAssertFalse(GazetteerRouteResolver.isPlaceKey("nowhere"))
    }

    func testUnknownPlaceReturnsNil() {
        XCTAssertNil(GazetteerRouteResolver.lookup("narnia"))
        XCTAssertFalse(GazetteerRouteResolver.isPlace(""))
    }

    func testHaversineZeroForSamePoint() {
        let manila = GeoPoint(lat: 14.5995, lon: 120.9842)
        XCTAssertEqual(GazetteerRouteResolver.haversineKm(manila, manila), 0, accuracy: 0.0001)
    }

    func testRouteBetweenKnownPlaces() {
        let route = resolver.route(from: "Manila", to: "Batangas")
        XCTAssertNotNil(route)
        XCTAssertTrue(route!.isEstimated)
        // Manila–Batangas is on the order of ~100 km by road.
        XCTAssertGreaterThan(route!.distanceKm, 70)
        XCTAssertLessThan(route!.distanceKm, 160)
    }

    func testRouteWithUnknownEndpointFails() {
        XCTAssertNil(resolver.route(from: "Manila", to: "Narnia"))
    }

    func testHaversineKnownDistance() {
        // Manila -> Cebu straight line is ~570 km.
        let manila = GeoPoint(lat: 14.5995, lon: 120.9842)
        let cebu = GeoPoint(lat: 10.3157, lon: 123.8854)
        XCTAssertEqual(GazetteerRouteResolver.haversineKm(manila, cebu), 570, accuracy: 40)
    }
}
