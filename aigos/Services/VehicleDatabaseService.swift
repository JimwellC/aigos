//
//  VehicleDatabaseService.swift
//  aigos
//
//  Offline vehicle knowledge base. Loads the bundled VehicleDatabase.json (top PH
//  models + motorcycles), answers "what's the km/L of X?" style questions from
//  Talk to aigos, and — when nothing matches — falls back to typical ranges by
//  category (Tier 2). Fuzzy matching tolerates typos ("vious" → Vios). Zero net.
//

import Foundation

struct VehicleEntry: Decodable, Equatable {
    let make: String
    let model: String
    let variant: String?
    let kmL: Double
    let fuel: String        // FuelType raw value
    let type: String        // VehicleType raw value
    let category: String

    var displayName: String {
        if let variant { return "\(make) \(model) \(variant)" }
        return "\(make) \(model)"
    }
    /// Make + model without the variant suffix, e.g. "Toyota Land Cruiser".
    var makeModel: String { "\(make) \(model)" }
    var fuelType: FuelType { FuelType(rawValue: fuel) ?? .unleaded91 }
    var vehicleType: VehicleType { VehicleType(rawValue: type) ?? .car }
}

/// A structured answer to a vehicle question. `text` is always shown; when
/// `efficiencyKmL` is set, Talk offers a "Use this efficiency" button.
struct VehicleAnswer: Equatable {
    let text: String
    var efficiencyKmL: Double? = nil
    var fuelType: FuelType? = nil
    var vehicleType: VehicleType? = nil
    var suggestedName: String? = nil
    var offersAddVehicle: Bool = false   // show an "Add a vehicle" button (no efficiency)
}

enum VehicleDatabase {
    static let entries: [VehicleEntry] = load()

    private struct File: Decodable { let vehicles: [VehicleEntry] }
    private static func load() -> [VehicleEntry] {
        guard let url = Bundle.main.url(forResource: "VehicleDatabase", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data) else { return [] }
        return file.vehicles
    }

    // MARK: - Public entry point

    /// Classify a Talk message as a vehicle question and answer it. Returns nil
    /// when the message isn't about a vehicle (so Talk falls through to trips).
    static func answer(for text: String, entries: [VehicleEntry] = VehicleDatabase.entries) -> VehicleAnswer? {
        let q = text.lowercased()

        // 1. "Is Premium 95 worth it?"
        if q.contains("premium") && (q.contains("worth") || q.contains("better") || q.contains("need") || q.contains("should i") || q.contains("vs unleaded")) {
            return VehicleAnswer(text: "For most everyday Filipino cars, Unleaded 91 is what the manufacturer recommends. Premium 95 won't improve performance unless your car specifically requires it — check your fuel cap or manual.")
        }

        // 2. "How do I know my km/L?"
        if (q.contains("how do i know") || q.contains("how to know") || q.contains("how can i know") || q.contains("how do i compute") || q.contains("how to compute"))
            && (q.contains("km/l") || q.contains("kml") || q.contains("efficiency") || q.contains("mileage") || q.contains("consumption")) {
            return VehicleAnswer(text: "Fill your tank full and note the odometer. Drive normally, then refill and note the litres added. Divide the kilometres driven by those litres — that's your real km/L. Average a few tanks for a reliable number.")
        }

        // 2b. "What SUVs are fuel efficient?" / "Best car for long drives?" /
        //     "Cheapest to run motorcycle?" → rank the top few by km/L.
        if let ranking = categoryBest(q, entries: entries) { return ranking }

        let entry = find(text, entries: entries)
        let age = extractAge(text)

        // 2c. "[model] is a SUV" — a category clarification, not a location query.
        if let stated = statedCategory(in: q), let entry {
            let (label, range) = correctionBlurb(for: entry, stated: stated)
            return VehicleAnswer(
                text: "Got it! The \(entry.makeModel) is \(label). Based on its category, it typically gets around \(range). Want me to use about \(fmt(entry.kmL)) km/L for your calculation?",
                efficiencyKmL: entry.kmL, fuelType: entry.fuelType,
                vehicleType: entry.vehicleType, suggestedName: entry.makeModel)
        }

        // 3. Age / engine-wear question.
        if age != nil || q.contains("years old") || q.contains("year old") || q.contains("yr old") || q.contains("older car") {
            if let entry {
                let realistic = round(entry.kmL * 0.85 * 10) / 10
                return VehicleAnswer(
                    text: "Older cars typically get 10–20% less than rated due to engine wear. The \(entry.displayName) is rated \(fmt(entry.kmL)) km/L, so I'd use about \(fmt(realistic)) km/L as a realistic estimate.",
                    efficiencyKmL: realistic, fuelType: entry.fuelType,
                    vehicleType: entry.vehicleType, suggestedName: entry.displayName)
            }
            return VehicleAnswer(text: "Older cars typically get 10–20% less than their rated efficiency due to engine wear. A good rule of thumb is rated × 0.85 for a realistic estimate.")
        }

        // 4. Fuel-type question.
        if let entry, q.contains("fuel type") || q.contains("what fuel") || q.contains("which fuel") || q.contains("what gas") || q.contains("runs on") || q.contains("gas type") {
            return VehicleAnswer(
                text: "The \(entry.displayName) runs on \(entry.fuelType.label) — that's what most owners use and what the maker recommends.",
                efficiencyKmL: entry.kmL, fuelType: entry.fuelType,
                vehicleType: entry.vehicleType, suggestedName: entry.displayName)
        }

        // 5. Found a model → give its rated km/L + offer to use it.
        if let entry {
            return VehicleAnswer(
                text: "The \(entry.displayName) gets about \(fmt(entry.kmL)) km/L in typical Philippine driving. Want me to use this?",
                efficiencyKmL: entry.kmL, fuelType: entry.fuelType,
                vehicleType: entry.vehicleType, suggestedName: entry.displayName)
        }

        // 6. Tier 2 — no model, but it reads like a vehicle question.
        if looksLikeVehicleQuery(q, entries: entries) {
            if let (label, range) = categoryRange(for: q) {
                return VehicleAnswer(text: "I don't have that exact model in my database yet. Based on its category (\(label)), similar vehicles get around \(range). You can set your exact figure when you add the vehicle.", offersAddVehicle: true)
            }
            return VehicleAnswer(text: "I don't have that model in my database yet. Most everyday cars here get around 12–17 km/L. You can set your exact figure when you add the vehicle.", offersAddVehicle: true)
        }

        return nil
    }

    // MARK: - Matching

    /// Find the best matching entry for free text (exact keys first, then fuzzy).
    static func find(_ text: String, entries: [VehicleEntry] = VehicleDatabase.entries) -> VehicleEntry? {
        let q = stripped(text)
        let matches = entries.filter { e in keys(for: e).contains { q.contains($0) } }
        if !matches.isEmpty { return disambiguate(matches, query: text.lowercased()) }
        return fuzzyFind(text, entries: entries)
    }

    /// Among same-model candidates, pick the variant the query names, else first.
    private static func disambiguate(_ matches: [VehicleEntry], query: String) -> VehicleEntry {
        if matches.count == 1 { return matches[0] }
        for e in matches {
            guard let variant = e.variant?.lowercased() else { continue }
            let core = variant.replacingOccurrences(of: "l", with: "")   // "1.5l" -> "1.5"
            if query.contains(variant) || query.contains(core) { return e }
        }
        if query.contains("diesel"), let d = matches.first(where: { $0.fuel == "diesel" }) { return d }
        if query.contains("gas"), let g = matches.first(where: { ($0.variant ?? "").lowercased() == "gas" }) { return g }
        return matches[0]
    }

    private static func fuzzyFind(_ text: String, entries: [VehicleEntry]) -> VehicleEntry? {
        let qWords = words(text).filter { $0.count >= 4 }
        guard !qWords.isEmpty else { return nil }
        var best: (entry: VehicleEntry, dist: Int)?
        for e in entries {
            for mw in modelWords(e) {
                for qw in qWords {
                    let d = levenshtein(qw, mw)
                    let tolerance = (mw.count >= 6 && qw.count >= 6) ? 2 : 1
                    if d <= tolerance, best == nil || d < best!.dist {
                        best = (e, d)
                    }
                }
            }
        }
        return best?.entry
    }

    // MARK: - Tier 2 category ranges

    /// Typical km/L ranges by category (spec Tier 2).
    static func categoryRange(for q: String) -> (label: String, range: String)? {
        let diesel = q.contains("diesel")
        if q.contains("motor") || q.contains("bike") || q.contains("scooter") {
            if q.contains("400") || q.contains("big bike") || q.contains("bigbike") {
                return ("big bike, 400cc+", "20–30 km/L")
            }
            if q.contains("150") || q.contains("155") || q.contains("160") {
                return ("150–160cc motorcycle", "35–45 km/L")
            }
            return ("125cc motorcycle", "45–55 km/L")
        }
        if q.contains("pickup") || q.contains("truck") { return ("diesel pickup", "9–12 km/L") }
        if q.contains("van") { return ("diesel van", "9–11 km/L") }
        if q.contains("suv") || q.contains("crossover") {
            return diesel ? ("diesel SUV", "10–13 km/L") : ("gas SUV", "10–13 km/L")
        }
        if q.contains("sedan") || q.contains("car") || q.contains("hatch") {
            if q.contains("1.8") || q.contains("2.0") || q.contains("2.4") || q.contains("2.5") {
                return ("1.8–2.0L sedan", "12–15 km/L")
            }
            return ("1.3–1.6L sedan", "14–17 km/L")
        }
        return nil
    }

    // MARK: - Category clarification ("[model] is a SUV")

    private static let categoryWords = ["suv", "crossover", "mpv", "sedan", "hatchback",
                                        "hatch", "van", "pickup", "truck", "motorcycle", "motorbike"]

    /// A category the user states the vehicle belongs to ("... is a SUV").
    private static func statedCategory(in q: String) -> String? {
        let cue = q.contains("is a ") || q.contains("is an ") || q.contains("it's a ")
            || q.contains("it is a ") || q.contains("is the ") || q.contains("is my ")
        guard cue else { return nil }
        return categoryWords.first { q.contains($0) }
    }

    /// A friendly category label + typical range for a correction reply. Large
    /// SUVs (Land Cruiser, Patrol, Prado…) read as "full-size".
    private static func correctionBlurb(for entry: VehicleEntry, stated: String) -> (label: String, range: String) {
        let model = entry.model.lowercased()
        let fullSize = ["land cruiser", "patrol", "prado", "sequoia", "suburban", "lc300"]
        switch stated {
        case "suv", "crossover":
            if fullSize.contains(where: { model.contains($0) }) {
                return ("a full-size SUV", "8–11 km/L (diesel) or 7–9 km/L (gas)")
            }
            return ("an SUV", "9–13 km/L (diesel) or 8–11 km/L (gas)")
        case "mpv":                 return ("an MPV", "10–14 km/L")
        case "van":                 return ("a van", "9–12 km/L")
        case "pickup", "truck":     return ("a pickup", "9–12 km/L (diesel)")
        case "hatchback", "hatch":  return ("a hatchback", "15–20 km/L")
        case "motorcycle", "motorbike": return ("a motorcycle", "40–55 km/L")
        default:                    return ("a sedan", "13–17 km/L")
        }
    }

    // MARK: - "Most fuel-efficient X" rankings

    private static func categoryBest(_ q: String, entries: [VehicleEntry]) -> VehicleAnswer? {
        let intent = ["efficient", "best", "cheapest", "economical", "most km",
                      "save gas", "save on gas", "matipid", "sulit", "longest range"]
        guard intent.contains(where: { q.contains($0) }) else { return nil }

        let label: String
        let filter: (VehicleEntry) -> Bool
        if q.contains("motor") || q.contains("bike") || q.contains("scooter") {
            label = "motorcycles"; filter = { $0.vehicleType == .motorcycle }
        } else if q.contains("suv") || q.contains("crossover") {
            label = "SUVs"; filter = { $0.category.contains("suv") }
        } else if q.contains("van") || q.contains("mpv") {
            label = "vans/MPVs"; filter = { $0.category.contains("van") || $0.category.contains("mpv") }
        } else if q.contains("pickup") || q.contains("truck") {
            label = "pickups"; filter = { $0.category.contains("pickup") }
        } else if q.contains("sedan") {
            label = "sedans"; filter = { $0.category.contains("sedan") }
        } else if q.contains("car") || q.contains("long drive") || q.contains("long-drive")
                    || q.contains("road trip") || q.contains("long trip") || q.contains("highway") {
            label = "cars"; filter = { $0.vehicleType == .car }
        } else {
            return nil   // "best" with no recognizable category — let other handlers try.
        }

        let top = topEfficient(matching: filter, entries: entries, limit: 3)
        guard top.count >= 2 else { return nil }
        let lines = top.map { "• \($0.makeModel) — \(fmt($0.kmL)) km/L" }.joined(separator: "\n")
        return VehicleAnswer(text: "Here are the most fuel-efficient \(label) in my list:\n\(lines)\n\nAsk me to estimate a trip with any of them!")
    }

    /// Top-N entries matching `filter`, best variant per model, highest km/L first.
    static func topEfficient(matching filter: (VehicleEntry) -> Bool,
                             entries: [VehicleEntry] = VehicleDatabase.entries, limit: Int = 3) -> [VehicleEntry] {
        var bestByModel: [String: VehicleEntry] = [:]
        for e in entries where filter(e) {
            let key = e.makeModel.lowercased()
            if let cur = bestByModel[key], cur.kmL >= e.kmL { continue }
            bestByModel[key] = e
        }
        return Array(bestByModel.values.sorted { $0.kmL > $1.kmL }.prefix(limit))
    }

    // MARK: - Helpers

    private static func looksLikeVehicleQuery(_ q: String, entries: [VehicleEntry]) -> Bool {
        let cues = ["km/l", "kml", "liters per", "litres per", "km per", "per liter", "per litre",
                    "my car", "i have a", "i have an", "i drive", "fuel type", "how much gas",
                    "efficiency", "mileage", "consumption", "what fuel"]
        if cues.contains(where: { q.contains($0) }) { return true }
        let makes = Set(entries.map { $0.make.lowercased() })
        return makes.contains { q.contains($0) }
    }

    static func fmt(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }

    /// Lowercased, alphanumerics only — for substring key checks.
    static func stripped(_ s: String) -> String {
        String(s.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
    }

    private static func words(_ s: String) -> [String] {
        s.lowercased().split { !$0.isLetter }.map(String.init)
    }

    private static func modelWords(_ e: VehicleEntry) -> [String] {
        e.model.lowercased().split { !$0.isLetter }.map(String.init).filter { $0.count >= 4 }
    }

    /// Match keys: full stripped model (≥3), make+model, and alphabetic model words (≥3).
    static func keys(for e: VehicleEntry) -> [String] {
        var ks = Set<String>()
        let sm = stripped(e.model)
        if sm.count >= 3 { ks.insert(sm) }
        ks.insert(stripped(e.make) + sm)
        for w in e.model.lowercased().split(whereSeparator: { !$0.isLetter }) where w.count >= 3 {
            ks.insert(String(w))
        }
        return Array(ks)
    }

    /// Extract an "N years old" age from text (ignores model years like 2022).
    static func extractAge(_ text: String) -> Int? {
        let t = text.lowercased().replacingOccurrences(of: "-", with: " ")
        guard let re = try? NSRegularExpression(pattern: #"(\d{1,2})\s*(year|yr)s?\s*(old)?"#) else { return nil }
        let range = NSRange(t.startIndex..., in: t)
        guard let m = re.firstMatch(in: t, range: range), m.numberOfRanges >= 2,
              let r = Range(m.range(at: 1), in: t) else { return nil }
        // Require "old" nearby or the word "year" — avoids matching bare "2022".
        return Int(t[r])
    }

    static func levenshtein(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var prev = Array(0...b.count)
        var curr = [Int](repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            curr[0] = i
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                curr[j] = min(prev[j] + 1, curr[j - 1] + 1, prev[j - 1] + cost)
            }
            swap(&prev, &curr)
        }
        return prev[b.count]
    }
}
