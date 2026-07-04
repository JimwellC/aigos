//
//  TravelRoutes.swift
//  aigos
//
//  Typical domestic FERRY and FLIGHT routes/fares (FerryDatabase.json /
//  FlightDatabase.json) for the multi-modal, cross-island trip breakdown. These
//  are reference ESTIMATES only — aigos calculates fuel; ferry/flight fares vary
//  with season, booking date, and vehicle size. Always shown with the disclaimer.
//

import Foundation

enum TravelRoutes {

    struct FlightRoute: Decodable, Equatable {
        let from: String, to: String
        let hours: Double
        let minPHP: Double, maxPHP: Double
    }

    struct FerryRoute: Decodable, Equatable {
        let from: String, to: String
        let hours: Double
        let minPHP: Double, maxPHP: Double
        let operatorName: String?
        let withCarPHP: Double?
        enum CodingKeys: String, CodingKey {
            case from, to, hours, minPHP, maxPHP
            case operatorName = "operator"
            case withCarPHP
        }
    }

    private struct FlightDB: Decodable { let routes: [FlightRoute]; let airlines: [String] }
    private struct FerryDB: Decodable { let routes: [FerryRoute]; let operators: [String: String] }

    private static let flightDB: FlightDB = load("FlightDatabase") ?? FlightDB(routes: [], airlines: [])
    private static let ferryDB: FerryDB = load("FerryDatabase") ?? FerryDB(routes: [], operators: [:])

    private static func load<T: Decodable>(_ name: String) -> T? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static var airlines: [String] { flightDB.airlines }

    /// A flight between two hub cities (either direction).
    static func flight(from: String, to: String) -> FlightRoute? {
        flightDB.routes.first { match($0.from, from) && match($0.to, to) }
            ?? flightDB.routes.first { match($0.from, to) && match($0.to, from) }
    }

    /// A ferry between two hub cities (either direction).
    static func ferry(from: String, to: String) -> FerryRoute? {
        ferryDB.routes.first { match($0.from, from) && match($0.to, to) }
            ?? ferryDB.routes.first { match($0.from, to) && match($0.to, from) }
    }

    private static func match(_ a: String, _ b: String) -> Bool {
        a.lowercased() == b.lowercased()
    }

    /// Standard disclaimer appended to every sea/air response.
    static let disclaimer = """
    aigos calculates FUEL cost only. Ferry and flight prices are ESTIMATES for reference — actual fares depend on season, how early you book, and vehicle size (for ro-ro). Check operator sites for live rates: Cebu Pacific (cebupacificair.com), PAL (philippineairlines.com), 2GO (travel.2go.com.ph), OceanJet (oceanjet.net).
    """
}
