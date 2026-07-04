//
//  RouteAnalyzerTests.swift
//  aigosTests
//
//  Road-type auto-detection from an online MKDirections route (string-based, so
//  it's testable without MapKit).
//

import XCTest
@testable import aigos

final class RouteAnalyzerTests: XCTestCase {

    func testNamedExpresswayDetectsHighway() {
        let s = RouteAnalyzer.detect(
            stepTexts: ["Take NLEX toward Clark", "Continue on NLEX"], routeName: "NLEX",
            origin: "Manila", destination: "Clark",
            originProvince: "Metro Manila", destinationProvince: "Pampanga")
        XCTAssertEqual(s?.roadType, .highway)
        XCTAssertEqual(s?.label, "Highway (NLEX)")
    }

    func testMountainDestinationDetectsMountain() {
        let s = RouteAnalyzer.detect(
            stepTexts: ["Take Marcos Highway"], routeName: "",
            origin: "Manila", destination: "Baguio",
            originProvince: "Metro Manila", destinationProvince: "Benguet")
        XCTAssertEqual(s?.roadType, .mountain)
    }

    func testMountainTakesPriorityOverExpressway() {
        // Manila→Baguio uses NLEX/SCTEX, but the destination is a highland.
        let s = RouteAnalyzer.detect(
            stepTexts: ["Take NLEX", "Take SCTEX", "Take Kennon Road"], routeName: "NLEX",
            origin: "Manila", destination: "Baguio",
            originProvince: "Metro Manila", destinationProvince: "Benguet")
        XCTAssertEqual(s?.roadType, .mountain)
    }

    func testBothEndpointsMetroManilaDetectsCity() {
        let s = RouteAnalyzer.detect(
            stepTexts: ["Turn left onto EDSA", "Turn right on Ortigas Ave"], routeName: "EDSA",
            origin: "Makati", destination: "Quezon City",
            originProvince: "Metro Manila", destinationProvince: "Metro Manila")
        XCTAssertEqual(s?.roadType, .city)
        XCTAssertEqual(s?.label, "City (Metro Manila)")
    }

    func testGenericTollwayWordDetectsHighway() {
        let s = RouteAnalyzer.detect(
            stepTexts: ["Merge onto the Expressway"], routeName: "",
            origin: "Bacoor", destination: "Sta. Rosa",
            originProvince: "Cavite", destinationProvince: "Laguna")
        XCTAssertEqual(s?.roadType, .highway)
        XCTAssertEqual(s?.label, "Highway")
    }

    func testNoStrongSignalReturnsNil() {
        let s = RouteAnalyzer.detect(
            stepTexts: ["Turn right on Rizal Street", "Continue on the national road"], routeName: "",
            origin: "San Pablo", destination: "Lucena",
            originProvince: "Laguna", destinationProvince: "Quezon")
        XCTAssertNil(s)
    }

    func testMetroManilaRecognition() {
        XCTAssertTrue(RouteAnalyzer.isMetroManila("Metro Manila"))
        XCTAssertTrue(RouteAnalyzer.isMetroManila("NCR"))
        XCTAssertFalse(RouteAnalyzer.isMetroManila("Cavite"))
        XCTAssertFalse(RouteAnalyzer.isMetroManila(nil))
    }
}
