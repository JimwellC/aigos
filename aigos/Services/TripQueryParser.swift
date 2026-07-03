//
//  TripQueryParser.swift
//  aigos
//
//  Deterministic, fully-offline natural-language understanding for "Talk to aigos"
//  queries like "How much to drive Pampanga to Manila in my Vios?" (Section 7,
//  Feature 07). Extracts origin, destination, and (optionally) the named vehicle by
//  reusing the gazetteer. Works on every device with zero dependencies; when Apple
//  Intelligence is available it can be swapped for model-guided extraction behind
//  the same TripQuery contract.
//

import Foundation

struct TripQuery: Equatable {
    let origin: String
    let destination: String
    let vehicleName: String?          // the vehicle named in the query, if any
    var traffic: TrafficCondition?    // detected condition, if mentioned
    var acOn: Bool?                   // "with AC" / "no aircon"
    var rushHour: Bool?               // "during rush hour"
    var load: VehicleLoad?            // "with cargo" / "full load" / passengers
}

/// Trip-condition hints detected in free text (no route required).
struct TripHints: Equatable {
    var traffic: TrafficCondition?
    var acOn: Bool?
    var rushHour: Bool?
    var load: VehicleLoad?

    var hasAny: Bool { traffic != nil || acOn != nil || rushHour != nil || load != nil }
}

enum TripQueryParser {
    private static let stopwords: Set<String> = [
        "how", "much", "many", "will", "would", "it", "cost", "costs", "to",
        "drive", "driving", "go", "going", "get", "getting", "from", "the", "a",
        "an", "me", "my", "i", "if", "what", "whats", "what's", "is", "in", "on",
        "for", "of", "between", "and", "trip", "fuel", "gas", "price", "by",
        "with", "car", "travel", "need", "about", "roughly", "spend", "up",
        // Condition keywords — detected separately by detectHints(), so strip them
        // here to keep place parsing clean (e.g. "manila to batangas heavy traffic").
        "traffic", "heavy", "moderate", "light", "standstill", "gridlock", "bumper",
        "edsa", "rush", "hour", "peak", "jam", "aircon", "ac", "air", "con",
        "cargo", "load", "loaded", "hauling", "passenger", "passengers", "during",
        "friday", "weekday", "family", "people", "clear", "free", "flowing",
        "full", "some", "bad", "no", "without", "off", "not", "moving",
    ]

    static func parse(_ text: String, vehicles: [VehicleProfile],
                      personalPlaces: [PersonalPlace] = []) -> TripQuery? {
        // Configured personal-place names count as valid places (e.g. "home").
        let aliases = Set(PlaceResolver.aliasMap(personalPlaces).keys)
        let hints = detectHints(text.lowercased())
        var lower = text.lowercased()
        for p in ["?", "!", ".", ",", "'"] {
            lower = lower.replacingOccurrences(of: p, with: " ")
        }
        // "between X and Y" → treat "and" as the separator.
        if lower.contains("between") {
            lower = lower.replacingOccurrences(of: " and ", with: " to ")
        }

        // 1. Match a named vehicle by any distinctive word in its name, then strip
        //    it so it can't pollute place parsing.
        let matched = vehicles.first { v in
            v.name.lowercased().split(separator: " ")
                .contains { $0.count >= 3 && lower.contains($0) }
        }
        if let matched {
            for w in matched.name.lowercased().split(separator: " ") where w.count >= 3 {
                lower = lower.replacingOccurrences(of: String(w), with: " ")
            }
        }

        let tokens = lower.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard !tokens.isEmpty else { return nil }

        // 2. Primary: split around each "to" and take the first split whose sides
        //    both resolve to known places.
        for idx in tokens.indices where tokens[idx] == "to" {
            if let origin = longestPlace(Array(tokens[..<idx]), aliases: aliases),
               let destination = longestPlace(Array(tokens[(idx + 1)...]), aliases: aliases),
               origin != destination {
                return makeQuery(origin, destination, matched?.name, hints)
            }
        }

        // 3. Fallback: keyword scan handles reversed phrasing ("to Y from X").
        if let destination = placeAfter("to", in: tokens, aliases: aliases),
           let origin = placeAfter("from", in: tokens, aliases: aliases),
           origin != destination {
            return makeQuery(origin, destination, matched?.name, hints)
        }

        // 4. Destination only + a configured "Home" shortcut → assume origin = Home
        //    (e.g. "how much to drive to Makati during rush hour?").
        if aliases.contains("home"),
           let destination = placeAfter("to", in: tokens, aliases: aliases),
           destination != "home" {
            return makeQuery("home", destination, matched?.name, hints)
        }

        return nil
    }

    private static func makeQuery(_ origin: String, _ destination: String, _ vehicle: String?, _ h: TripHints) -> TripQuery {
        TripQuery(origin: origin, destination: destination, vehicleName: vehicle,
                  traffic: h.traffic, acOn: h.acOn, rushHour: h.rushHour, load: h.load)
    }

    /// Detect trip-condition hints from arbitrary text — used for follow-up
    /// messages like "same trip but with heavy traffic".
    static func hints(from text: String) -> TripHints { detectHints(text.lowercased()) }

    /// Detect trip-condition hints from the raw query (traffic, rush hour, AC, load).
    private static func detectHints(_ text: String) -> TripHints {
        var h = TripHints()

        // Traffic — check the most severe phrases first. "EDSA" implies standstill.
        if text.contains("standstill") || text.contains("bumper") || text.contains("gridlock")
            || text.contains("edsa") || text.contains("not moving") {
            h.traffic = .standstill
        } else if text.contains("heavy traffic") || text.contains("bad traffic")
            || text.contains("traffic jam") || text.contains("heavy") {
            h.traffic = .heavy
        } else if text.contains("moderate traffic") || text.contains("some traffic") || text.contains("moderate") {
            h.traffic = .moderate
        } else if text.contains("light traffic") || text.contains("no traffic")
            || text.contains("clear road") || text.contains("free flowing") {
            h.traffic = .light
        }

        // Rush hour.
        if text.contains("rush hour") || text.contains("rush-hour")
            || text.contains("peak hour") || text.contains("rush") {
            h.rushHour = true
        }

        // Aircon — negative phrasing wins.
        if text.contains("no ac") || text.contains("without ac") || text.contains("ac off")
            || text.contains("no aircon") || text.contains("without aircon") || text.contains("aircon off") {
            h.acOn = false
        } else if text.contains("with ac") || text.contains(" ac on") || text.contains("aircon")
            || text.contains("air-con") || text.contains("air con") {
            h.acOn = true
        }

        // Load.
        if text.contains("cargo") || text.contains("loaded with") || text.contains("hauling") {
            h.load = .cargo
        } else if text.contains("full load") || text.contains("fully loaded") || text.contains("full of") {
            h.load = .full
        } else if text.contains("passenger") || text.contains("with family")
            || text.contains("3 people") || text.contains("4 people") {
            h.load = .moderate
        }

        return h
    }

    private static func isPlace(_ candidate: String, aliases: Set<String>) -> Bool {
        aliases.contains(candidate) || GazetteerRouteResolver.isPlace(candidate)
    }

    private static func isPlaceKey(_ word: String, aliases: Set<String>) -> Bool {
        aliases.contains(word) || GazetteerRouteResolver.isPlaceKey(word)
    }

    /// Longest leading run of (stopword-stripped) tokens that names a place — so
    /// multi-word names like "cagayan de oro" resolve fully. Personal aliases
    /// (e.g. "home") count as places too.
    private static func longestPlace(_ tokens: [String], aliases: Set<String>) -> String? {
        let content = tokens.filter { !stopwords.contains($0) }
        guard !content.isEmpty else { return nil }
        var best: String?
        var phrase: [String] = []
        for w in content {
            // Don't merge two adjacent distinct places (e.g. "tagaytay makati"):
            // once we already have a match, stop before a word that is itself a place.
            if best != nil, isPlaceKey(w, aliases: aliases) { break }
            phrase.append(w)
            let candidate = phrase.joined(separator: " ")
            if isPlace(candidate, aliases: aliases) {
                best = candidate
            } else if best != nil {
                break   // stop once a matched phrase stops extending
            }
        }
        return best
    }

    private static func placeAfter(_ keyword: String, in tokens: [String], aliases: Set<String>) -> String? {
        guard let i = tokens.firstIndex(of: keyword) else { return nil }
        return longestPlace(Array(tokens[(i + 1)...]), aliases: aliases)
    }
}
