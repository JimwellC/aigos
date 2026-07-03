//
//  RouteResolver.swift
//  aigos
//
//  Offline distance estimation (v1.0).
//
//  aigos estimates trip distance entirely offline from a bundled gazetteer of
//  Philippine provinces, cities, districts and common landmarks/road aliases —
//  straight-line (haversine) distance scaled by a road-winding factor. Places are
//  validated via autocomplete so free-text like "J" is never accepted.
//
//  `RouteResolver` is the seam: v1.1 can drop in precise turn-by-turn routing
//  (OSRM + a bundled OpenStreetMap PH extract) behind the same protocol.
//

import Foundation

struct GeoPoint: Sendable, Equatable {
    let lat: Double
    let lon: Double
}

struct RouteResult: Sendable, Equatable {
    let distanceKm: Double
    /// True when the distance is an approximation (gazetteer/haversine) rather
    /// than a precise road route. Drives the "estimated" label in the UI.
    let isEstimated: Bool
}

/// One searchable place: a canonical key + display title, a subtitle (province /
/// region / district), a coordinate, and any aliases ("BGC", "QC", "EDSA").
struct GazetteerEntry: Sendable, Equatable, Identifiable {
    let title: String
    let subtitle: String
    let point: GeoPoint
    let aliases: [String]

    /// Canonical lowercase key (from the title).
    var key: String { title.lowercased() }
    var id: String { key }
}

protocol RouteResolver {
    func route(from origin: String, to destination: String) -> RouteResult?
}

struct GazetteerRouteResolver: RouteResolver {

    /// Empirical multiplier: PH road distance runs ~30% longer than straight line.
    static let windingFactor = 1.30

    /// All searchable places (see GazetteerData).
    static let entries: [GazetteerEntry] = GazetteerData.entries

    /// key + every alias → entry, for O(1) resolution.
    static let index: [String: GazetteerEntry] = {
        var d: [String: GazetteerEntry] = [:]
        for entry in entries {
            if d[entry.key] == nil { d[entry.key] = entry }
            for alias in entry.aliases where d[alias] == nil { d[alias] = entry }
        }
        return d
    }()

    /// Back-compat: every resolvable key/alias → its coordinate.
    static let places: [String: GeoPoint] = index.mapValues { $0.point }

    func route(from origin: String, to destination: String) -> RouteResult? {
        guard let a = Self.lookup(origin), let b = Self.lookup(destination) else { return nil }
        return Self.estimate(from: a, to: b)
    }

    /// Estimated road distance between two points (haversine × winding factor).
    static func estimate(from a: GeoPoint, to b: GeoPoint) -> RouteResult {
        let road = haversineKm(a, b) * windingFactor
        return RouteResult(distanceKm: (road * 10).rounded() / 10, isEstimated: true)
    }

    /// Resolve a place name/alias to a coordinate. Exact match first, then a
    /// deterministic substring fallback (longest contained key).
    static func lookup(_ query: String) -> GeoPoint? {
        entry(for: query)?.point
    }

    /// Resolve to the full entry (used by autocomplete / display).
    static func entry(for query: String) -> GazetteerEntry? {
        let key = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }
        if let exact = index[key] { return exact }
        if let longest = index.keys.filter({ key.contains($0) }).max(by: { $0.count < $1.count }) {
            return index[longest]
        }
        if let shortest = index.keys.filter({ $0.contains(key) }).min(by: { $0.count < $1.count }) {
            return index[shortest]
        }
        return nil
    }

    /// Whether a free-text fragment names a known place.
    static func isPlace(_ query: String) -> Bool { lookup(query) != nil }

    /// Whether a single word is itself a gazetteer key or alias (e.g. "makati",
    /// "bgc"). Used by the NL parser to avoid merging two adjacent places.
    static func isPlaceKey(_ word: String) -> Bool {
        index[word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)] != nil
    }

    /// Great-circle distance in kilometres.
    static func haversineKm(_ a: GeoPoint, _ b: GeoPoint) -> Double {
        let earthRadiusKm = 6371.0
        let dLat = (b.lat - a.lat) * .pi / 180
        let dLon = (b.lon - a.lon) * .pi / 180
        let lat1 = a.lat * .pi / 180
        let lat2 = b.lat * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2)
            + sin(dLon / 2) * sin(dLon / 2) * cos(lat1) * cos(lat2)
        return earthRadiusKm * 2 * atan2(sqrt(h), sqrt(1 - h))
    }
}
