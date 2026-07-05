//
//  ConversationContext.swift
//  aigos
//
//  Conversation memory for "Talk to aigos". The chat keeps a small in-memory
//  `TalkContext` (the last trip AND the last vehicle discussed, plus the last
//  numeric result) so a message with no route of its own can be understood as a
//  FOLLOW-UP that modifies the previous one — "with heavy traffic", "round trip?",
//  "split between 4", "if I use diesel?", "what about the 1.5?", plus Tagalog
//  equivalents ("balikan?", "kada isa", "paano kung diesel").
//
//  This file is PURE logic (no SwiftData / no UI) so the classifier and the
//  numeric transforms are unit-tested directly. The view holds the mutable
//  `TalkContext`, resolves places/vehicles, and renders the before/after diff.
//  Context is in-memory only and is cleared when the Talk sheet closes.
//

import Foundation

/// What the last message was about — lets a follow-up target the right layer
/// (a trip vs a vehicle) when both have been discussed.
enum TalkTopic: Equatable { case trip, vehicle, toll, fuel, general }

/// The remembered conversation state. Two layers are tracked independently (a
/// trip and a vehicle) so "with that car" can apply a remembered vehicle to a
/// remembered trip.
struct TalkContext: Equatable {
    // Trip layer
    var tripQuery: TripQuery?          // last full trip (route + conditions + vehicle)
    var lastDistanceKm: Double?
    var lastCostPHP: Double?
    var lastFuelType: FuelType?
    var passengers: Int?               // explicit head-count, for per-person maths

    // Vehicle layer (kept separate from the trip)
    var lastVehicleModel: String?      // e.g. "Vios" — a database model referenced

    // Meta
    var lastTopic: TalkTopic = .general
    var updatedAt: Date?

    var hasTrip: Bool { tripQuery != nil }

    /// "Manila → Baguio" for the follow-up context indicator.
    var routeLabel: String? {
        guard let q = tripQuery else { return nil }
        return "\(q.origin.capitalized) → \(q.destination.capitalized)"
    }

    /// True when more than `minutes` have elapsed since the last message.
    func isStale(now: Date, minutes: Double = 5) -> Bool {
        guard let updatedAt else { return false }
        return now.timeIntervalSince(updatedAt) > minutes * 60
    }

    mutating func reset() { self = TalkContext() }
}

/// The kind of follow-up a message represents, once we know there's context.
enum FollowUpKind: Equatable {
    case modifyConditions(TripHints)   // traffic / AC / load changes on the same trip
    case swapFuel(FuelType)            // "if I use diesel?", "with premium instead"
    case roundTrip                     // "round trip?", "balikan?"
    case perPerson(Int?)               // "split between 4", "kada isa" (nil = infer)
    case howFar                        // "how far?", "gaano kalayo/katagal?"
    case cheaper                       // "how can I make it cheaper?", "mas mura?"
    case confirmYes                    // "yes" / "oo" / "sige" / "use it"
    case confirmNo                     // "no" / "hindi" / "ayaw ko"
    case acknowledge                   // "ok" / "thanks" / "salamat"
    case reset                         // "new trip" / "iba naman" — clear context
    case repeatLast                    // "the same", bare "what about"
    case none
}

enum FollowUp {

    // MARK: - Backwards-compatible helpers (still used by the trip merge path)

    private static let phrases = [
        "same trip", "same route", "same one", "same drive", "what about",
        "what if", "how about", "instead", "and if", "but ",
    ]

    static func isFollowUp(_ text: String, hints: TripHints, vehicleChanged: Bool) -> Bool {
        if hints.hasAny || vehicleChanged { return true }
        let lower = " \(text.lowercased()) "
        return phrases.contains { lower.contains($0) }
    }

    /// Layer new hints (and an optional new vehicle) onto the previous query.
    static func merge(previous: TripQuery, hints: TripHints, vehicleName: String?) -> TripQuery {
        TripQuery(
            origin: previous.origin,
            destination: previous.destination,
            vehicleName: vehicleName ?? previous.vehicleName,
            traffic: hints.traffic ?? previous.traffic,
            acOn: hints.acOn ?? previous.acOn,
            rushHour: hints.rushHour ?? previous.rushHour,
            load: hints.load ?? previous.load
        )
    }

    // MARK: - Classification

    /// Classify a message as a follow-up. Pure — no place/vehicle resolution.
    static func classify(_ raw: String) -> FollowUpKind {
        let q = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let bare = q.trimmingCharacters(in: CharacterSet(charactersIn: ".!?, "))
        let padded = " \(q) "

        // 1. Reset / new topic.
        if has(padded, ["new trip", "new question", "different question", "different trip",
                        "start over", "reset", "forget that", "iba naman", "bagong tanong",
                        "ibang tanong", "bagong biyahe"]) { return .reset }

        // 2. Confirmations — whole short messages only (so "no traffic" isn't a "no").
        if yes.contains(bare) { return .confirmYes }
        if no.contains(bare) { return .confirmNo }
        if ack.contains(bare) { return .acknowledge }

        // 3. Round trip.
        if has(padded, ["round trip", "round-trip", "return trip", "both ways",
                        "back and forth", "there and back", "balikan", "pabalik at pauwi"])
            || bare == "round" || bare == "roundtrip" { return .roundTrip }

        // 4. Per person / split.
        if has(padded, ["per person", "each person", "per head", "each of us", "split",
                        "divide", "between us", "share the cost", "kada isa", "kada tao",
                        "hati", "hatian", "paghatian", "magkano kami"]) {
            return .perPerson(headCount(in: q))
        }

        // 5. Distance / duration recall.
        if has(padded, ["how far", "how long", "how many km", "how many kilometer",
                        "how many kilometre", "what's the distance", "whats the distance",
                        "the distance", "gaano kalayo", "gaano katagal", "ilang km",
                        "ilang kilometro", "ilang oras"]) { return .howFar }

        // 6. Cheaper / savings.
        if has(padded, ["cheaper", "cheapest", "make it cheaper", "lower the cost",
                        "lower cost", "reduce the cost", "save on this", "how to save",
                        "mas mura", "pinakamura", "pwede bang mas mura", "paano tipid",
                        "make it lower"]) { return .cheaper }

        // 7. Fuel swap (needs an explicit fuel word, not a bare number).
        if let f = fuelSwap(in: raw) { return .swapFuel(f) }

        // 8. Condition changes (traffic / AC / load). Start from the English hint
        //    detector, then layer Tagalog cues it doesn't cover.
        var hints = TripQueryParser.hints(from: raw)
        // Tagalog "walang aircon" = WITHOUT aircon. The English detector sees the
        // substring "aircon" and wrongly flips AC on, so this negative must override.
        if has(padded, ["walang aircon", "walang ac", "patay aircon", "walang air"]) {
            hints.acOn = false
        } else if hints.acOn == nil, has(padded, ["may aircon", "naka aircon", "naka-aircon", "bukas aircon"]) {
            hints.acOn = true
        }
        if hints.traffic == nil, has(padded, ["mabigat na trapiko", "matindi ang trapiko",
                                              "matrapik", "trapik", "may trapiko"]) {
            hints.traffic = .heavy
        }
        // A head-count with a people cue becomes a load factor ("4 passengers",
        // "lima kami"). Gated so a stray number never sets the load.
        let mentionsPeople = has(padded, ["passenger", "people", "pax", "person",
                                          "kami", "tao", "sakay", "kasama", "family"])
        if mentionsPeople, let n = headCount(in: q), n >= 3 {
            hints.load = n >= 5 ? .full : .moderate
        }
        if hints.hasAny { return .modifyConditions(hints) }

        // 9. A bare follow-up phrase with no explicit change → repeat the last trip.
        if has(padded, ["what about", "how about", "same trip", "same route", "the same",
                        "same one", "ganun din", "ulitin", "same but"]) { return .repeatLast }

        return .none
    }

    // MARK: - Extractors

    private static let yes: Set<String> = [
        "yes", "yep", "yeah", "yup", "sure", "ok yes", "use it", "use this", "use that",
        "apply", "apply it", "do it", "go", "go ahead", "please do", "oo", "opo", "sige",
        "sige na", "oo nga", "tama", "yes please",
    ]
    private static let no: Set<String> = [
        "no", "nope", "nah", "dont", "don't", "skip", "cancel", "hindi", "ayaw",
        "ayaw ko", "huwag", "wag", "no thanks",
    ]
    private static let ack: Set<String> = [
        "ok", "okay", "okey", "k", "got it", "cool", "nice", "great", "alright",
        "noted", "gotcha", "understood",
    ]

    /// A fuel grade named for a swap — requires an explicit fuel word so a bare
    /// number ("4 people") never counts as a grade.
    static func fuelSwap(in raw: String) -> FuelType? {
        let t = raw.lowercased()
        let fuelWords = ["diesel", "premium", "unleaded", "gasoline", "petrol",
                         "e-gas", "e gas", "egas", "ethanol"]
        guard fuelWords.contains(where: { t.contains($0) }) else { return nil }
        return FuelType.detect(in: raw)
    }

    /// A head-count for splitting a cost — digits ("4 people", "split 4 ways",
    /// "for 3") or Tagalog number words ("lima" = 5, "ilan kami apat" = 4).
    static func headCount(in text: String) -> Int? {
        let t = text.lowercased()
        // Digits, e.g. "4 people", "split 4", "between 5", "for 3".
        let scanner = t.split { !$0.isNumber }.compactMap { Int($0) }
        if let n = scanner.first(where: { (2...12).contains($0) }) { return n }
        // Tagalog / Filipino number words.
        let words: [(String, Int)] = [
            ("dalawa", 2), ("tatlo", 3), ("apat", 4), ("lima", 5), ("anim", 6),
            ("pito", 7), ("walo", 8), ("siyam", 9), ("sampu", 10),
            ("two", 2), ("three", 3), ("four", 4), ("five", 5), ("six", 6),
            ("seven", 7), ("eight", 8),
        ]
        for (w, n) in words where t.contains(w) { return n }
        return nil
    }

    private static func has(_ padded: String, _ needles: [String]) -> Bool {
        needles.contains { padded.contains($0) }
    }
}
