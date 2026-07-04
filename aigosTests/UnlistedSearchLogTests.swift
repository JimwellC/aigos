//
//  UnlistedSearchLogTests.swift
//  aigosTests
//
//  The private "not listed" search log (local UserDefaults only).
//

import XCTest
@testable import aigos

final class UnlistedSearchLogTests: XCTestCase {

    override func setUp() { UnlistedSearchLog.clear() }
    override func tearDown() { UnlistedSearchLog.clear() }

    func testRecordsNonEmptyQueries() {
        UnlistedSearchLog.record("Tesla Model S")
        UnlistedSearchLog.record("  ")          // blank — ignored
        UnlistedSearchLog.record("")            // empty — ignored
        XCTAssertEqual(UnlistedSearchLog.all, ["Tesla Model S"])
    }

    func testRankedByFrequency() {
        UnlistedSearchLog.record("BYD Han")
        UnlistedSearchLog.record("byd han")
        UnlistedSearchLog.record("Ora Good Cat")
        let ranked = UnlistedSearchLog.ranked
        XCTAssertEqual(ranked.first?.query, "byd han")
        XCTAssertEqual(ranked.first?.count, 2)
    }
}
