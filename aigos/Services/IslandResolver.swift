//
//  IslandResolver.swift
//  aigos
//
//  Maps a place to the drivable landmass ("island") it sits on, so aigos can tell
//  when a trip crosses water and can't be driven end-to-end (e.g. Angeles → Davao).
//  Province → landmass comes from IslandDatabase.json; a few city overrides handle
//  separate islands inside a mainland province (Boracay in Aklan, Siargao in
//  Surigao del Norte, Samal off Davao). "Landmasses" are road-connected, so
//  bridged islands (Leyte↔Samar via San Juanico, Mactan↔Cebu) count as one.
//

import Foundation

enum IslandResolver {

    private struct DB: Decodable {
        let provinces: [String: String]
        let cityOverrides: [String: String]
        let hubs: [String: String]
    }

    private static let db: DB = {
        guard let url = Bundle.main.url(forResource: "IslandDatabase", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let db = try? JSONDecoder().decode(DB.self, from: data) else {
            return DB(provinces: [:], cityOverrides: [:], hubs: [:])
        }
        return db
    }()

    /// Landmass for a gazetteer entry — a city override (by title) wins over the
    /// province mapping (so Boracay ≠ Panay, Siargao ≠ Mindanao).
    static func island(for entry: GazetteerEntry) -> String? {
        let title = entry.title.lowercased()
        if let override = db.cityOverrides.first(where: { title.contains($0.key) })?.value {
            return override
        }
        return db.provinces[entry.subtitle.lowercased()]
    }

    /// Landmass for a place name (resolved through the gazetteer).
    static func island(forPlace name: String) -> String? {
        GazetteerRouteResolver.entry(for: name).flatMap(island(for:))
    }

    /// True when both places resolve to *different* landmasses (a sea/air crossing).
    /// False when either can't be resolved (we don't block unknown places).
    static func isCrossIsland(_ a: String, _ b: String) -> Bool {
        guard let ia = island(forPlace: a), let ib = island(forPlace: b) else { return false }
        return ia != ib
    }

    /// The main departure hub city (airport/port) for a landmass.
    static func hub(for island: String) -> String? { db.hubs[island] }
}
