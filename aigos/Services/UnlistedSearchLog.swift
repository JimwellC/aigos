//
//  UnlistedSearchLog.swift
//  aigos
//
//  Records searches where the user tapped "My car is not in the list" so future
//  releases can prioritise which vehicles to add. PRIVATE by design: stored only
//  in local UserDefaults on this device, never transmitted anywhere (the app has
//  no backend and no analytics SDK — see the privacy declaration). Capped so it
//  can't grow without bound.
//

import Foundation

enum UnlistedSearchLog {
    private static let key = "unlistedVehicleSearches"
    private static let cap = 200

    /// Record a non-empty "not listed" search query (local only).
    static func record(_ query: String) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        var log = UserDefaults.standard.stringArray(forKey: key) ?? []
        log.append(q)
        if log.count > cap { log.removeFirst(log.count - cap) }
        UserDefaults.standard.set(log, forKey: key)
    }

    /// All recorded queries (oldest first).
    static var all: [String] { UserDefaults.standard.stringArray(forKey: key) ?? [] }

    /// Queries by frequency, most-requested first — the v1.1 "add these" list.
    static var ranked: [(query: String, count: Int)] {
        Dictionary(grouping: all.map { $0.lowercased() }, by: { $0 })
            .map { ($0.key, $0.value.count) }
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0 < $1.0 }
    }

    static func clear() { UserDefaults.standard.removeObject(forKey: key) }
}
