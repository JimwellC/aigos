//
//  DrivingScore.swift
//  aigos
//
//  A 0–100 fuel-efficiency score for a vehicle's learned driving profile
//  (Feature 4). Pure/deterministic so it's fully testable. Components:
//  Speed vs optimal 30 · AC efficiency 15 · Smooth driving (GPS) 15 ·
//  Rush-hour avoidance 20 · Maintenance 20.
//

import Foundation

struct DrivingScore: Equatable {
    let speed: Int          // /30
    let ac: Int             // /15
    let smoothness: Int     // /15
    let rushHour: Int       // /20
    let maintenance: Int    // /20

    var total: Int { min(100, max(0, speed + ac + smoothness + rushHour + maintenance)) }

    var label: String {
        switch total {
        case 90...:  "🏆 Fuel Master"
        case 75...89: "⭐ Smart Driver"
        case 60...74: "👍 Getting There"
        default:      "📈 Room to Improve"
        }
    }
}

enum DrivingScorer {

    /// Score from raw inputs (pure). `gpsSmoothness` is 0–1 (1 = smoothest), or nil
    /// when there's no tracked-trip data yet (then a neutral score is used).
    static func score(highwaySpeedKmh: Double, acUsageRate: Double, rushHourFraction: Double,
                      maintenance: MaintenanceStatus, gpsSmoothness: Double?) -> DrivingScore {
        // Speed: full 30 in the 80–100 optimal band; falls off with the speed factor.
        let factor = CalculationEngine.speedFactor(forSpeed: highwaySpeedKmh)   // 1.00 optimal … 1.22
        let speed = points(30, of: max(0, 1 - (factor - 1.0) / 0.25))

        // AC: heavy AC use leaves the most room to improve (windows at low speed).
        let ac = points(15, of: 1 - 0.4 * clamp01(acUsageRate))

        // Smoothness from GPS-tracked accuracy; neutral (≈11/15) without data.
        let smoothness = gpsSmoothness.map { points(15, of: clamp01($0)) } ?? 11

        // Rush-hour avoidance.
        let rushHour = points(20, of: 1 - clamp01(rushHourFraction))

        // Maintenance.
        let maint: Int
        switch maintenance {
        case .wellMaintained: maint = 20
        case .average:        maint = 13
        case .overduePMS:     maint = 5
        }

        return DrivingScore(speed: speed, ac: ac, smoothness: smoothness, rushHour: rushHour, maintenance: maint)
    }

    /// Convenience: pull the inputs from the models.
    static func score(for vehicle: VehicleProfile, trips: [TripRecord], trackedTrips: [TrackedTrip] = []) -> DrivingScore {
        let profile = vehicle.drivingProfile
        let hwy = profile?.avgActualHighwaySpeed ?? profile?.avgHighwaySpeedKmh ?? 90
        let acRate = trips.isEmpty
            ? (profile?.acUsageRate ?? (profile?.usesACByDefault ?? true ? 1 : 0))
            : Double(trips.filter(\.acWasOn).count) / Double(trips.count)
        let rushFrac = trips.isEmpty ? 0.3
            : Double(trips.filter { $0.wasRushHour || $0.traffic == .heavy || $0.traffic == .standstill }.count) / Double(trips.count)
        let done = trackedTrips.filter { $0.isCompleted }
        let smooth: Double? = done.isEmpty ? nil : done.reduce(0) { $0 + $1.accuracyPercent } / Double(done.count) / 100.0
        return score(highwaySpeedKmh: hwy, acUsageRate: acRate, rushHourFraction: rushFrac,
                     maintenance: vehicle.maintenanceStatus, gpsSmoothness: smooth)
    }

    // MARK: - Helpers

    private static func points(_ max: Int, of fraction: Double) -> Int {
        Int((Double(max) * clamp01(fraction)).rounded())
    }
    private static func clamp01(_ v: Double) -> Double { min(1, max(0, v)) }
}
