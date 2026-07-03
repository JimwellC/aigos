//
//  FollowUp.swift
//  aigos
//
//  Conversational follow-ups for "Talk to aigos". A message with no route of its
//  own (e.g. "same trip but it's EDSA on a Friday", "what about with cargo",
//  "in my truck") is treated as a modification of the last trip: same origin and
//  destination, with newly-mentioned conditions/vehicle layered on top.
//

import Foundation

enum FollowUp {

    /// Phrases that signal "apply this to the previous trip".
    private static let phrases = [
        "same trip", "same route", "same one", "same drive", "what about",
        "what if", "how about", "instead", "and if", "but ",
    ]

    /// Whether `text` should be treated as a follow-up on a prior trip. True when
    /// it carries new conditions, names a different vehicle, or uses a follow-up
    /// phrase — but only matters when there IS a previous trip to modify.
    static func isFollowUp(_ text: String, hints: TripHints, vehicleChanged: Bool) -> Bool {
        if hints.hasAny || vehicleChanged { return true }
        let lower = " \(text.lowercased()) "
        return phrases.contains { lower.contains($0) }
    }

    /// Layer new hints (and an optional new vehicle) onto the previous query.
    /// Unspecified fields keep the previous value, so conditions accumulate.
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
}
