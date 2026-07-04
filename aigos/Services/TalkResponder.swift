//
//  TalkResponder.swift
//  aigos
//
//  Two small, fully-offline helpers that make "Talk to aigos" feel human:
//  · TalkNormalizer — rewrites common Filipino trip phrasings into the English
//    patterns the parser/vehicle brain already understand.
//  · TalkSmallTalk — greetings, thanks, goodbye, confusion, and a friendly
//    redirect when the question has nothing to do with fuel or cars.
//  Deterministic; no network, no model.
//

import Foundation

enum TalkNormalizer {
    private static let cues = ["magkano", "papunta", "papuntang", "gaano", "kalayo",
                               "gasolina", "anong gas", "hanggang", "papupunta"]

    /// Rewrite Filipino trip/fuel phrasings to their English equivalents. Only
    /// touches text that actually contains a Filipino cue, so English is untouched.
    static func normalize(_ text: String) -> String {
        let lower = text.lowercased()
        guard cues.contains(where: { lower.contains($0) }) else { return text }

        var t = lower
        // Longest phrases first so partial ones don't fire early.
        let subs: [(String, String)] = [
            ("magkano ang gasolina", "how much to drive"),
            ("magkano ang gas", "how much to drive"),
            ("magkano papunta", "how much to drive to"),
            ("magkano", "how much"),
            ("anong gasolina para sa", "what fuel"),
            ("anong gas para sa", "what fuel"),
            ("anong gasolina sa", "what fuel"),
            ("anong klaseng gasolina", "what fuel"),
            ("anong gasolina", "what fuel"),
            ("anong gas", "what fuel"),
            ("gaano kalayo ang", "how far"),
            ("gaano kalayo", "how far"),
            ("papuntang", "to"),
            ("papunta sa", "to"),
            ("papunta", "to"),
            (" mula sa ", " from "),
            (" mula ", " from "),
            (" ang ", " "),
            (" sa ", " to "),
            (" ng ", " "),
            (" para sa ", " for "),
        ]
        for (a, b) in subs { t = t.replacingOccurrences(of: a, with: b) }
        return t
    }
}

enum TalkSmallTalk {
    /// The catch-all when a question has nothing to do with fuel, cars, or trips.
    static let unrelatedRedirect =
        "I'm aigos — your fuel trip assistant! I'm best at calculating fuel costs and answering car questions. Try asking me something like “How much to drive to Baguio?” or “What is the km/L of Vios?” 🚌"

    private static let greet = ["hi", "hello", "hey", "helow", "yo", "hoy", "kamusta", "kumusta", "musta"]
    private static let thanks = ["thanks", "thank", "salamat", "ty", "thx", "tenks"]
    private static let bye = ["bye", "goodbye", "paalam", "babay", "cya", "byebye"]

    /// A short reply for greetings / thanks / goodbye / confusion — or nil when
    /// the message isn't small talk (so the caller keeps trying trip/vehicle).
    static func quickReply(for text: String) -> String? {
        let q = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let words = q.split { !$0.isLetter }.map(String.init)
        let short = words.count <= 3

        // Confusion — exact-ish phrases (checked first; may be a lone "what?").
        if q == "what" || q == "what?" || q == "huh" || q == "ha" || q == "come again"
            || q.contains("i don't understand") || q.contains("i dont understand")
            || q.contains("don't get it") || q.contains("dont get it")
            || q.contains("what do you mean") || q.contains("hindi ko maintindihan")
            || q.contains("di ko maintindihan") {
            return "Try asking me like this: “How much gas from Manila to Cebu?” or “What fuel does Vios use?”"
        }
        if short, words.contains(where: greet.contains) {
            return "Kamusta! I'm aigos 🚌 Ask me about fuel costs, car efficiency, or any trip in the Philippines!"
        }
        if (short && words.contains(where: thanks.contains)) || q.contains("thank you") || q.contains("maraming salamat") {
            return "Walang anuman! Ingat sa daan! 🚌"
        }
        if (short && words.contains(where: bye.contains)) || q.contains("see you") || q.contains("see yah") {
            return "Paalam! Drive safe! 🚌"
        }
        return nil
    }

    /// Final fallback: nudge toward the calculator when the message looks like an
    /// unresolved trip, otherwise the friendly redirect.
    static func fallback(for text: String) -> String {
        let q = text.lowercased()
        let tripCues = ["to ", " from", "drive", "how much", "how far", "distance",
                        "gas", "fuel", "trip", " km", "going", "route", "papunta", "layo"]
        if tripCues.contains(where: { q.contains($0) }) {
            return "I couldn't find that place. Try typing it in the calculator and picking from the suggestions."
        }
        return unrelatedRedirect
    }
}
