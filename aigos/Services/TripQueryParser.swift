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
    let vehicleName: String?   // the vehicle named in the query, if any
}

enum TripQueryParser {
    private static let stopwords: Set<String> = [
        "how", "much", "many", "will", "would", "it", "cost", "costs", "to",
        "drive", "driving", "go", "going", "get", "getting", "from", "the", "a",
        "an", "me", "my", "i", "if", "what", "whats", "what's", "is", "in", "on",
        "for", "of", "between", "and", "trip", "fuel", "gas", "price", "by",
        "with", "car", "travel", "need", "about", "roughly", "spend", "up",
    ]

    static func parse(_ text: String, vehicles: [VehicleProfile]) -> TripQuery? {
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
            if let origin = longestPlace(Array(tokens[..<idx])),
               let destination = longestPlace(Array(tokens[(idx + 1)...])),
               origin != destination {
                return TripQuery(origin: origin, destination: destination, vehicleName: matched?.name)
            }
        }

        // 3. Fallback: keyword scan handles reversed phrasing ("to Y from X").
        if let destination = placeAfter("to", in: tokens),
           let origin = placeAfter("from", in: tokens),
           origin != destination {
            return TripQuery(origin: origin, destination: destination, vehicleName: matched?.name)
        }

        return nil
    }

    /// Longest leading run of (stopword-stripped) tokens that names a place — so
    /// multi-word names like "cagayan de oro" resolve fully.
    private static func longestPlace(_ tokens: [String]) -> String? {
        let content = tokens.filter { !stopwords.contains($0) }
        guard !content.isEmpty else { return nil }
        var best: String?
        var phrase: [String] = []
        for w in content {
            // Don't merge two adjacent distinct places (e.g. "tagaytay makati"):
            // once we already have a match, stop before a word that is itself a place.
            if best != nil, GazetteerRouteResolver.isPlaceKey(w) { break }
            phrase.append(w)
            let candidate = phrase.joined(separator: " ")
            if GazetteerRouteResolver.isPlace(candidate) {
                best = candidate
            } else if best != nil {
                break   // stop once a matched phrase stops extending
            }
        }
        return best
    }

    private static func placeAfter(_ keyword: String, in tokens: [String]) -> String? {
        guard let i = tokens.firstIndex(of: keyword) else { return nil }
        return longestPlace(Array(tokens[(i + 1)...]))
    }
}
