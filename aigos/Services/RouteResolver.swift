//
//  RouteResolver.swift
//  aigos
//
//  Offline distance resolution.
//
//  ── OSRM PROTOTYPE NOTE ─────────────────────────────────────────────────────
//  The spec's target is OSRM + a bundled Philippine OpenStreetMap dataset for
//  true road-distance routing, fully offline (Section 7). OSRM is a C++ routing
//  *server*, so embedding it in an iOS app is the single highest technical risk
//  in the build and is deliberately deferred past this scaffold.
//
//  This file is the Sprint-1 prototype that de-risks the "user can calculate"
//  goal TODAY, fully offline, via a protocol boundary:
//
//    • `RouteResolver` is the seam. Drop in an `OSRMRouteResolver` later without
//      touching any view.
//    • `GazetteerRouteResolver` estimates distance from a small bundled table of
//      PH city coordinates (haversine × a road-winding factor). Good enough to
//      demo end-to-end; clearly labelled "estimated" in the UI.
//    • Manual distance entry is always available and overrides everything — the
//      spec's designated fallback if the OSRM bundle proves too large (>100MB).
//  ────────────────────────────────────────────────────────────────────────────
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

protocol RouteResolver {
    /// Resolve a driving distance between two free-text place names, or nil if
    /// either place is unknown (caller then falls back to manual entry).
    func route(from origin: String, to destination: String) -> RouteResult?
}

/// Offline distance estimator backed by a small gazetteer of PH population
/// centres. Straight-line (haversine) distance is scaled by a winding factor to
/// approximate real road distance.
struct GazetteerRouteResolver: RouteResolver {

    /// Empirical multiplier: PH road distance runs ~30% longer than straight line.
    private let windingFactor = 1.30

    /// Seed gazetteer — expand freely; replaced by OSRM in a later sprint.
    static let places: [String: GeoPoint] = [
        "manila": .init(lat: 14.5995, lon: 120.9842),
        "quezon city": .init(lat: 14.6760, lon: 121.0437),
        "makati": .init(lat: 14.5547, lon: 121.0244),
        "pasig": .init(lat: 14.5764, lon: 121.0851),
        "taguig": .init(lat: 14.5176, lon: 121.0509),
        "antipolo": .init(lat: 14.5932, lon: 121.1760),
        "cavite": .init(lat: 14.4791, lon: 120.8970),
        "tagaytay": .init(lat: 14.1153, lon: 120.9621),
        "calamba": .init(lat: 14.2117, lon: 121.1653),
        "santa rosa": .init(lat: 14.3122, lon: 121.1114),
        "lipa": .init(lat: 13.9411, lon: 121.1622),
        "batangas": .init(lat: 13.7565, lon: 121.0583),
        "lucena": .init(lat: 13.9373, lon: 121.6170),
        "malolos": .init(lat: 14.8433, lon: 120.8113),
        "cabanatuan": .init(lat: 15.4869, lon: 120.9675),
        "tarlac": .init(lat: 15.4755, lon: 120.5960),
        "san fernando": .init(lat: 15.0286, lon: 120.6898), // Pampanga
        "angeles": .init(lat: 15.1450, lon: 120.5887),
        "clark": .init(lat: 15.1855, lon: 120.5601),
        "subic": .init(lat: 14.8797, lon: 120.2350),
        "olongapo": .init(lat: 14.8292, lon: 120.2828),
        "baguio": .init(lat: 16.4023, lon: 120.5960),
        "dagupan": .init(lat: 16.0431, lon: 120.3339),
        "vigan": .init(lat: 17.5747, lon: 120.3869),
        "laoag": .init(lat: 18.1978, lon: 120.5936),
        "tuguegarao": .init(lat: 17.6132, lon: 121.7270),
        "naga": .init(lat: 13.6218, lon: 123.1948),
        "legazpi": .init(lat: 13.1391, lon: 123.7438),
        "cebu": .init(lat: 10.3157, lon: 123.8854),
        "bacolod": .init(lat: 10.6407, lon: 122.9689),
        "iloilo": .init(lat: 10.7202, lon: 122.5621),
        "davao": .init(lat: 7.1907, lon: 125.4553),
        "cagayan de oro": .init(lat: 8.4542, lon: 124.6319),
        "zamboanga": .init(lat: 6.9214, lon: 122.0790),
    ]

    func route(from origin: String, to destination: String) -> RouteResult? {
        guard let a = lookup(origin), let b = lookup(destination) else { return nil }
        let straight = Self.haversineKm(a, b)
        let road = (straight * windingFactor)
        let rounded = (road * 10).rounded() / 10
        return RouteResult(distanceKm: rounded, isEstimated: true)
    }

    /// Fuzzy place lookup — exact key, then a substring match either way.
    private func lookup(_ query: String) -> GeoPoint? {
        let key = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }
        if let exact = Self.places[key] { return exact }
        return Self.places.first { key.contains($0.key) || $0.key.contains(key) }?.value
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
