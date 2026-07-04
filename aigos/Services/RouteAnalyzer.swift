//
//  RouteAnalyzer.swift
//  aigos
//
//  Suggests a RoadType from an online MKDirections route (Feature: route path +
//  auto-detect). Pure and string-based so it's unit-testable without MapKit:
//  MKDirections supplies the step instructions / route name / endpoint provinces,
//  and this picks Highway / City / Mountain. The user can always override in the
//  "How you'll drive" sheet — this only pre-selects a sensible default.
//
//  Heuristics (in priority order):
//   1. Mountain — an endpoint is a known Philippine highland (Baguio, Tagaytay…).
//      MKDirections has no elevation, so we match place names, per the spec.
//   2. Highway — the route uses a named expressway (NLEX/SLEX/SCTEX/Skyway…).
//   3. City    — both endpoints are within Metro Manila.
//

import Foundation

enum RouteAnalyzer {

    struct Suggestion: Equatable {
        let roadType: RoadType
        /// User-facing label, e.g. "Highway (NLEX)" or "City (Metro Manila)".
        let label: String
    }

    /// Named expressways → their display label. Keys are matched as lowercased
    /// substrings of the route text.
    static let expressways: [(key: String, name: String)] = [
        ("nlex", "NLEX"), ("slex", "SLEX"), ("sctex", "SCTEX"), ("tplex", "TPLEX"),
        ("cavitex", "CAVITEX"), ("clex", "CLEX"), ("naiax", "NAIAX"),
        ("naia expressway", "NAIAX"), ("skyway", "Skyway"), ("star tollway", "STAR Tollway"),
        ("star toll", "STAR Tollway"), ("muntinlupa-cavite", "MCX"), ("mcx", "MCX"),
        ("subic-clark", "SCTEX"), ("tarlac-pangasinan", "TPLEX"),
    ]

    /// Generic tollway/expressway words (used when no specific name is found).
    static let expresswayWords = ["expressway", "tollway", "toll way", "toll road"]

    /// Known highland / mountain destinations (elevation proxy — MKDirections has
    /// no elevation data, so we match names per the spec's Baguio/Tagaytay examples).
    static let mountainPlaces = [
        "baguio", "sagada", "banaue", "tagaytay", "kennon", "atok", "benguet",
        "bontoc", "la trinidad", "ambuklao", "marcos highway", "kennon road",
        "naguilian", "mountain province", "ifugao", "kibungan", "buguias",
    ]

    /// Analyze a route. `stepTexts` are the MKRoute step instructions; `routeName`
    /// is `MKRoute.name`; provinces are the gazetteer subtitles for the endpoints.
    static func detect(stepTexts: [String], routeName: String,
                       origin: String, destination: String,
                       originProvince: String?, destinationProvince: String?) -> Suggestion? {
        let endpoints = "\(origin) \(destination)".lowercased()
        let hay = (stepTexts + [routeName]).joined(separator: " ").lowercased()

        // 1. Mountain — an endpoint (or the route) names a known highland area.
        if mountainPlaces.contains(where: { endpoints.contains($0) || hay.contains($0) }) {
            return Suggestion(roadType: .mountain, label: "Mountain route")
        }
        // 2. Highway — a named expressway, else a generic tollway word.
        if let ex = expressways.first(where: { hay.contains($0.key) }) {
            return Suggestion(roadType: .highway, label: "Highway (\(ex.name))")
        }
        if expresswayWords.contains(where: { hay.contains($0) }) {
            return Suggestion(roadType: .highway, label: "Highway")
        }
        // 3. City — both endpoints are within Metro Manila.
        if isMetroManila(originProvince) && isMetroManila(destinationProvince) {
            return Suggestion(roadType: .city, label: "City (Metro Manila)")
        }
        return nil
    }

    static func isMetroManila(_ province: String?) -> Bool {
        guard let p = province?.lowercased() else { return false }
        return p.contains("metro manila") || p.contains("ncr")
    }
}
