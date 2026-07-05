//
//  PriceChatParser.swift
//  aigos
//
//  Recognises fuel-price intents in "Talk to aigos" messages so users can update
//  or check pump prices by chatting instead of opening the Prices tab. Pure,
//  offline, deterministic, and unit-tested — the view handles the confirmation
//  flow and persistence.
//
//  Handles English + Tagalog, e.g.
//    "Update Premium 95 to 73"      → .update(.premium95, 73)
//    "Palitan ang Premium 95 sa 73" → .update(.premium95, 73)
//    "Set diesel to 500"            → .updateInvalidPrice(.diesel, 500)
//    "Update premium 95"            → .updateMissingPrice(.premium95)
//    "Update all prices"            → .batch
//    "Magkano ang gasolina today?"  → .check
//

import Foundation

/// The recognised fuel-price intent (or `.none` when the message isn't about prices).
enum PriceChatIntent: Equatable {
    case update(FuelType, Double)          // valid fuel + valid price
    case updateInvalidPrice(FuelType, Double)  // fuel + a price outside 40–200
    case updateMissingPrice(FuelType)      // fuel recognised but no price given
    case updateUnknownFuel                 // an update request with no recognisable fuel
    case check                             // show the current prices
    case batch                             // update every fuel type, one by one
    case none
}

enum PriceChatParser {

    /// Sensible PH pump-price bounds (PHP/L). Outside this, ask the user to confirm.
    static let minPrice = 40.0
    static let maxPrice = 200.0

    static func isValidPrice(_ v: Double) -> Bool {
        v.isFinite && (minPrice...maxPrice).contains(v)
    }

    // MARK: - Fuel-type recognition (with short codes)

    /// Recognise a fuel grade, incl. short codes ("u91", "p95", "pd", "d") and the
    /// pump/RON names. Order matters — most specific first.
    static func fuelType(in text: String) -> FuelType? {
        let t = " " + text.lowercased() + " "
        let table: [(FuelType, [String])] = [
            (.premiumDiesel, ["premium diesel", "diesel plus", "diesel+", " pd ", "premium-diesel"]),
            (.eGasoline,     ["e-gasoline", "e gasoline", "egasoline", "ethanol", "e-gas", " e gas ", " egas "]),
            (.premium97,     ["premium 97", "premium97", " p97 ", " 97 ", "ron 97", "ron97"]),
            (.premium95,     ["premium 95", "premium95", " p95 ", " 95 ", "premium", "ron 95", "ron95"]),
            (.unleaded91,    ["unleaded 91", "unleaded91", " u91 ", " 91 ", "unleaded", "regular", "ron 91", "ron91"]),
            (.diesel,        ["diesel", " d "]),
        ]
        for (type, needles) in table where needles.contains(where: { t.contains($0) }) {
            return type
        }
        return nil
    }

    /// The RON/grade number baked into a fuel name (so it isn't mistaken for a price).
    private static func gradeNumber(_ f: FuelType) -> Int? {
        switch f {
        case .premium95: return 95
        case .premium97: return 97
        case .unleaded91: return 91
        default: return nil
        }
    }

    // MARK: - Number / price extraction

    /// Every decimal number in the text, in order.
    static func numbers(in text: String) -> [Double] {
        guard let re = try? NSRegularExpression(pattern: "[0-9]+(?:\\.[0-9]+)?") else { return [] }
        let ns = text as NSString
        return re.matches(in: text, range: NSRange(location: 0, length: ns.length))
            .compactMap { Double(ns.substring(with: $0.range)) }
    }

    /// The price in the message — the last number that isn't the fuel's grade number
    /// ("Premium 95 to 73" → 73, not 95). Nil when no price is present.
    static func priceValue(in text: String, fuel: FuelType?) -> Double? {
        let grade = fuel.flatMap(gradeNumber)
        return numbers(in: text).last { grade == nil || abs($0 - Double(grade!)) > 0.001 }
    }

    // MARK: - Intent classification

    private static let batchCues = [
        "update all", "all prices", "all the prices", "every price", "update lahat",
        "lahat ng presyo", "lahat ng price", "set all",
    ]
    private static let updateCues = [
        "update", " set ", "change", "adjust", "baguhin", "palitan", "bagong presyo",
        "gawing", "itakda", "i-set", "iset", "new price", "bagong price", "ilagay",
    ]
    private static let checkCues = [
        "current price", "current fuel", "show price", "show current", "show the price",
        "what is the price", "what's the price", "whats the price", "how much is",
        "price list", "list price", "prices", "fuel price", "gas price", "diesel price",
        "magkano", "presyo ng", "price ng", "kanina magkano", "check price", "check the price",
    ]

    static func parse(_ text: String) -> PriceChatIntent {
        let padded = " " + text.lowercased() + " "

        if batchCues.contains(where: { padded.contains($0) }) { return .batch }

        let fuel = fuelType(in: text)
        let mentionsPriceWord = ["price", "presyo", "gasolina", " gas ", "gasoline",
                                 "fuel", "petrol"].contains { padded.contains($0) }
        guard fuel != nil || mentionsPriceWord else { return .none }

        let price = priceValue(in: text, fuel: fuel)
        let hasUpdateVerb = updateCues.contains { padded.contains($0) }

        // Update attempt: an explicit update verb, OR a fuel named together with a price.
        if hasUpdateVerb || (fuel != nil && price != nil) {
            guard let fuel else { return .updateUnknownFuel }
            guard let price else { return .updateMissingPrice(fuel) }
            return isValidPrice(price) ? .update(fuel, price) : .updateInvalidPrice(fuel, price)
        }

        // A check only when it explicitly reads like one — NOT merely because a fuel
        // grade is named (else "diesel Innova km/L" or "with premium" would be stolen
        // from the vehicle / fuel-swap intents).
        if checkCues.contains(where: { padded.contains($0) }) {
            return .check
        }
        return .none
    }

    /// A bare price answer during the batch flow ("72.50", "skip"), independent of
    /// any fuel word.
    static func batchAnswer(_ text: String) -> BatchAnswer {
        let t = text.lowercased().trimmingCharacters(in: .whitespaces)
        if ["skip", "keep", "same", "next", "pass", "walang pagbabago", "wala"].contains(t) { return .skip }
        if ["cancel", "stop", "tapos", "tapos na", "quit", "exit", "wag na"].contains(t) { return .cancel }
        if let v = numbers(in: text).last {
            return isValidPrice(v) ? .price(v) : .invalid(v)
        }
        return .unclear
    }

    enum BatchAnswer: Equatable { case price(Double), invalid(Double), skip, cancel, unclear }

    // MARK: - Weekly-update reminder

    /// A reminder string when prices haven't changed in a week (fuel moves weekly on
    /// Tuesdays), else nil.
    static func staleReminder(lastUpdated: Date?, now: Date) -> String? {
        guard let lastUpdated, now.timeIntervalSince(lastUpdated) > 7 * 24 * 3600 else { return nil }
        return "⏰ It's been over a week since prices were updated. PH fuel prices change weekly (Tuesdays). Want me to help update them? Say “update all prices”."
    }
}
