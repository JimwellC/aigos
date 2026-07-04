//
//  FuelLogParser.swift
//  aigos
//
//  Parses "I just filled up 35 liters at Shell for 2,520 pesos" from Talk into a
//  FuelLogDraft. Offline + deterministic + testable.
//

import Foundation

enum FuelLogParser {

    private static let cues = ["filled up", "fill up", "fill-up", "gassed up", "gas up",
                               "just filled", "refuel", "refueled", "fueled up", "topped up",
                               "top up", "nagfill", "nag-gas", "nag gas", "nag-fill"]

    static func isFuelLog(_ text: String) -> Bool {
        let q = text.lowercased()
        return cues.contains { q.contains($0) }
    }

    static func parse(_ text: String) -> FuelLogDraft? {
        guard isFuelLog(text) else { return nil }
        return FuelLogDraft(liters: litres(in: text), totalCost: cost(in: text), stationName: station(in: text))
    }

    // MARK: - Field extraction

    private static func litres(in text: String) -> Double? {
        // "35 liters", "35L", "35.5 li"
        firstMatch(#"(\d+(?:\.\d+)?)\s*(?:liters|litres|liter|litre|li|l)\b"#, in: text.lowercased())
            .flatMap { Double($0) }
    }

    private static func cost(in text: String) -> Double? {
        let t = text.lowercased()
        // "for 2,520 pesos", "php 2520", "₱2,520", "2520 pesos"
        // NB: no bare "p" alternative — it would match "up 30" in "filled up 30L".
        for pattern in [#"([\d,]+(?:\.\d+)?)\s*(?:pesos|peso|php)"#,
                        #"(?:for|php|₱)\s*([\d,]+(?:\.\d+)?)"#] {
            if let s = firstMatch(pattern, in: t) {
                let cleaned = s.replacingOccurrences(of: ",", with: "")
                if let v = Double(cleaned), v >= 20 { return v }   // ignore tiny numbers (likely litres)
            }
        }
        return nil
    }

    private static func station(in text: String) -> String? {
        // "at Shell", "at Petron San Fernando" — capture up to "for"/a number/end.
        guard let s = firstMatch(#"\bat\s+([A-Za-z][A-Za-z0-9 '&\-\.]*?)(?:\s+for\b|\s+\d|[,.!?]|$)"#, in: text,
                                 caseInsensitive: true) else { return nil }
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed.capitalized
    }

    // MARK: - Regex helper

    private static func firstMatch(_ pattern: String, in text: String, caseInsensitive: Bool = false) -> String? {
        let opts: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
        guard let re = try? NSRegularExpression(pattern: pattern, options: opts) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let m = re.firstMatch(in: text, range: range), m.numberOfRanges >= 2,
              let r = Range(m.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }
}
