//
//  SuggestionEngine.swift
//  aigos
//
//  Personalized fuel-saving tips from the last 30 days of trips + the vehicle's
//  driving profile (Feature 4). Each carries an estimated PHP saving. Candidate
//  generation and the daily rotation are pure/testable; `SuggestionLog` persists
//  which tips were shown (so none repeat within 7 days).
//

import Foundation

enum SuggestionType: String { case speed, ac, timing, maintenance, fuelType }

struct Suggestion: Identifiable, Equatable {
    let type: SuggestionType
    let icon: String
    let title: String
    let detail: String
    let savingsPHP: Double?
    var id: String { type.rawValue }
}

enum SuggestionEngine {

    /// Eligible tips from the last 30 days of trips (pure).
    static func candidates(vehicle: VehicleProfile, trips: [TripRecord], now: Date,
                           currentFuelPrice: Double, unleaded91Price: Double) -> [Suggestion] {
        let recent = trips.filter { now.timeIntervalSince($0.calculatedAt) <= 30 * 24 * 3600 }
        let monthlyCost = recent.reduce(0) { $0 + $1.totalCostPHP }
        let rushCost = recent
            .filter { $0.wasRushHour || $0.traffic == .heavy || $0.traffic == .standstill }
            .reduce(0) { $0 + $1.totalCostPHP }

        var out: [Suggestion] = []

        // Speed — only when they habitually cruise fast on the highway.
        let hwy = vehicle.drivingProfile?.avgActualHighwaySpeed ?? vehicle.drivingProfile?.avgHighwaySpeedKmh ?? 90
        let factor = CalculationEngine.speedFactor(forSpeed: hwy)
        if hwy > 100, factor > 1.0, monthlyCost > 0 {
            let save = monthlyCost * (1 - 1 / factor)
            out.append(.init(type: .speed, icon: "gauge.with.dots.needle.50percent",
                             title: "Ease off the gas",
                             detail: "Cruising nearer ~90 km/h instead of \(Int(hwy)) ≈ save \(save.phpString)/month.",
                             savingsPHP: save))
        }

        // AC — heavy aircon use in city driving.
        let acRate = vehicle.drivingProfile?.acUsageRate ?? (vehicle.drivingProfile?.usesACByDefault ?? true ? 1 : 0)
        if acRate > 0.6, monthlyCost > 0 {
            let save = monthlyCost * 0.06
            out.append(.init(type: .ac, icon: "snowflake",
                             title: "Windows over aircon in slow traffic",
                             detail: "Open the windows below 60 km/h ≈ ~12% less fuel on city trips (~\(save.phpString)/month).",
                             savingsPHP: save))
        }

        // Timing — lots of rush-hour trips.
        if rushCost > 0, recent.count >= 3 {
            let save = rushCost * 0.2
            out.append(.init(type: .timing, icon: "clock.badge.checkmark",
                             title: "Beat the rush",
                             detail: "Leaving before 7 AM dodges the rush-hour crawl ≈ save ~20% (~\(save.phpString)) on those trips.",
                             savingsPHP: save))
        }

        // Maintenance — overdue PMS.
        if vehicle.maintenanceStatus == .overduePMS {
            let save = monthlyCost * 0.15
            out.append(.init(type: .maintenance, icon: "wrench.and.screwdriver.fill",
                             title: "Overdue for PMS",
                             detail: monthlyCost > 0 ? "An overdue service can cost ~15% more fuel — about \(save.phpString)/month. Worth booking."
                                                     : "An overdue service can cost ~15% more fuel. Worth booking soon.",
                             savingsPHP: monthlyCost > 0 ? save : nil))
        }

        // Fuel type — premium in an everyday car that likely doesn't need it.
        if vehicle.type == .car, vehicle.fuelType == .premium95 || vehicle.fuelType == .premium97,
           currentFuelPrice > unleaded91Price {
            let save = (currentFuelPrice - unleaded91Price) * vehicle.tankCapacityL
            out.append(.init(type: .fuelType, icon: "fuelpump.fill",
                             title: "Try Unleaded 91",
                             detail: "Most everyday cars run fine on Unleaded 91 — switching saves ~\(save.phpString)/tank. Check your fuel cap first.",
                             savingsPHP: save))
        }

        return out
    }

    /// Pick up to `limit`, preferring tips not shown in the last 7 days, rotating by
    /// day so the visible set changes daily (pure).
    static func pick(_ candidates: [Suggestion], recentlyShownAt: [String: Date],
                     now: Date, limit: Int = 3) -> [Suggestion] {
        let window: TimeInterval = 7 * 24 * 3600
        let day = Int(now.timeIntervalSince1970 / 86400)
        let n = max(candidates.count, 1)
        let ordered = candidates.enumerated().sorted { l, r in
            let lf = isFresh(l.element, recentlyShownAt, now, window)
            let rf = isFresh(r.element, recentlyShownAt, now, window)
            if lf != rf { return lf }                     // fresh (not shown in 7d) first
            return (l.offset + day) % n < (r.offset + day) % n   // daily rotation among equals
        }.map(\.element)
        return Array(ordered.prefix(limit))
    }

    private static func isFresh(_ s: Suggestion, _ shown: [String: Date], _ now: Date, _ window: TimeInterval) -> Bool {
        guard let d = shown[s.id] else { return true }
        return now.timeIntervalSince(d) >= window
    }
}

/// Persists which suggestions were shown (local UserDefaults only).
enum SuggestionLog {
    private static let key = "suggestionShownAt"

    static var shownAt: [String: Date] {
        (UserDefaults.standard.dictionary(forKey: key) as? [String: Date]) ?? [:]
    }

    static func record(_ suggestions: [Suggestion], at date: Date = Date()) {
        var d = shownAt
        for s in suggestions { d[s.id] = date }
        UserDefaults.standard.set(d, forKey: key)
    }

    static func clear() { UserDefaults.standard.removeObject(forKey: key) }
}
