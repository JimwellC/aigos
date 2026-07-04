//
//  PlaceResolver.swift
//  aigos
//
//  Resolves a free-text place to a coordinate, checking the user's PersonalPlace
//  shortcuts (e.g. "Home", "Office") BEFORE the nationwide gazetteer. This is what
//  lets "home to office" work. Matching on personal names is case-insensitive.
//

import Foundation

enum PlaceResolver {

    /// Lowercased names of configured (mapped) personal places → gazetteer key.
    static func aliasMap(_ personalPlaces: [PersonalPlace]) -> [String: String] {
        var map: [String: String] = [:]
        for place in personalPlaces where place.isConfigured {
            map[place.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)] = place.gazetteerKey
        }
        return map
    }

    /// Resolve one place name to a point — personal alias first, then gazetteer.
    static func point(for query: String, personalPlaces: [PersonalPlace]) -> GeoPoint? {
        // A map-picked location encodes its coordinate directly.
        if query.hasPrefix("@pin:") {
            let parts = query.dropFirst(5).split(separator: ",")
            guard parts.count == 2, let lat = Double(parts[0]), let lon = Double(parts[1]) else { return nil }
            return GeoPoint(lat: lat, lon: lon)
        }
        let key = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }
        // A personal place by name: prefer its precise map-picked coordinate,
        // then fall back to its legacy city-level gazetteer key.
        if let place = personalPlaces.first(where: {
            $0.isConfigured && $0.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == key
        }) {
            if let point = place.geoPoint { return point }
            if !place.gazetteerKey.isEmpty { return GazetteerRouteResolver.lookup(place.gazetteerKey) }
        }
        return GazetteerRouteResolver.lookup(query)
    }

    /// Estimate the distance between two place names, resolving personal aliases
    /// on either end first.
    static func route(from origin: String, to destination: String,
                      personalPlaces: [PersonalPlace]) -> RouteResult? {
        guard let a = point(for: origin, personalPlaces: personalPlaces),
              let b = point(for: destination, personalPlaces: personalPlaces) else { return nil }
        return GazetteerRouteResolver.estimate(from: a, to: b)
    }
}
