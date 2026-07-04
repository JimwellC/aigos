//
//  PlaceSearch.swift
//  aigos
//
//  Autocomplete suggestions for the origin/destination fields. The user's saved
//  personal places come first, then gazetteer matches on title or alias. Only
//  real places are ever suggested — random text like "J" yields nothing.
//

import Foundation

struct PlaceSuggestion: Equatable, Identifiable {
    let id: String
    let title: String        // display, e.g. "Bonifacio Global City"
    let subtitle: String     // "Metro Manila" / "Saved place"
    let resolveKey: String   // fed to PlaceResolver to get a coordinate
    let isPersonal: Bool
}

enum PlaceSearch {

    /// Up to `limit` suggestions for `query`. Empty/whitespace → no suggestions.
    static func suggestions(for query: String, personalPlaces: [PersonalPlace], limit: Int = 5) -> [PlaceSuggestion] {
        let q = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }

        var results: [PlaceSuggestion] = []
        var seenKeys = Set<String>()

        // 1. Personal places first (configured only).
        for place in personalPlaces where place.isConfigured {
            guard place.name.lowercased().contains(q) else { continue }
            results.append(PlaceSuggestion(
                id: "personal:\(place.id.uuidString)",
                title: place.name,
                subtitle: place.hasCoordinate ? "Saved place" : "Saved place · \(place.gazetteerKey.capitalized)",
                resolveKey: place.name,
                isPersonal: true
            ))
            if !place.gazetteerKey.isEmpty { seenKeys.insert(place.gazetteerKey.lowercased()) }
        }

        // 2. Gazetteer matches on title, key, or alias — prefix matches ranked first.
        let matched = GazetteerRouteResolver.entries.filter { entry in
            entry.key.contains(q) || entry.aliases.contains { $0.contains(q) }
        }
        let ranked = matched.sorted { a, b in
            let ra = rank(a, q), rb = rank(b, q)
            return ra != rb ? ra < rb : a.title.count < b.title.count
        }
        for entry in ranked {
            guard !seenKeys.contains(entry.key) else { continue }
            seenKeys.insert(entry.key)
            results.append(PlaceSuggestion(
                id: entry.key, title: entry.title, subtitle: entry.subtitle,
                resolveKey: entry.key, isPersonal: false
            ))
            if results.count >= limit { break }
        }

        return Array(results.prefix(limit))
    }

    /// The selection key for an *exact* place-name match (typed in full, or from a
    /// Saved/Talk draft), or nil for partial/random text. This is the validation
    /// gate — "J" or "man" returns nil, "Manila" or "bgc" returns a key.
    static func exactKey(_ text: String, personalPlaces: [PersonalPlace]) -> String? {
        let key = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }
        if let p = personalPlaces.first(where: { $0.isConfigured && $0.name.lowercased() == key }) {
            return p.name
        }
        return GazetteerRouteResolver.index[key] != nil ? key : nil
    }

    /// 0 = title prefix, 1 = alias prefix, 2 = title contains, 3 = alias contains.
    private static func rank(_ e: GazetteerEntry, _ q: String) -> Int {
        if e.key.hasPrefix(q) { return 0 }
        if e.aliases.contains(where: { $0.hasPrefix(q) }) { return 1 }
        if e.key.contains(q) { return 2 }
        return 3
    }
}
