//
//  TrackedTrip.swift
//  aigos
//
//  A GPS-recorded trip (v1.1 headline feature). Captured while the user drives so
//  aigos can compare the ESTIMATE against the ACTUAL distance/fuel/cost and, if
//  they choose, self-correct the vehicle's real-world efficiency. All GPS data is
//  stored on-device only and is never transmitted (privacy is locked).
//

import Foundation
import SwiftData

@Model
final class TrackedTrip {
    var id: UUID = UUID()
    var tripRecordId: UUID = UUID()          // the TripRecord this tracked drive belongs to

    /// The recorded route as a FLAT array [lat, lon, lat, lon, …] (SwiftData stores
    /// scalar arrays fine; `coordinatePairs` reconstitutes them).
    var routeCoordinates: [Double] = []

    // Actual (from GPS)
    var actualDistanceKm: Double = 0
    var actualDurationSeconds: Int = 0
    var actualAvgSpeedKmh: Double = 0
    var actualFuelL: Double = 0
    var actualCostPHP: Double = 0

    // Estimate (snapshotted at start)
    var estimatedDistanceKm: Double = 0
    var estimatedFuelL: Double = 0
    var estimatedCostPHP: Double = 0

    var accuracyPercent: Double = 0
    var startedAt: Date = Date()
    var endedAt: Date = Date()
    var isCompleted: Bool = false

    // Denormalised for display without a join.
    var vehicleName: String = ""
    var origin: String = ""
    var destination: String = ""

    init(
        tripRecordId: UUID,
        estimatedDistanceKm: Double,
        estimatedFuelL: Double,
        estimatedCostPHP: Double,
        vehicleName: String,
        origin: String,
        destination: String,
        startedAt: Date = Date()
    ) {
        self.id = UUID()
        self.tripRecordId = tripRecordId
        self.estimatedDistanceKm = estimatedDistanceKm
        self.estimatedFuelL = estimatedFuelL
        self.estimatedCostPHP = estimatedCostPHP
        self.vehicleName = vehicleName
        self.origin = origin
        self.destination = destination
        self.startedAt = startedAt
        self.endedAt = startedAt
    }

    /// The flat `[lat, lon, …]` array as `(lat, lon)` pairs.
    var coordinatePairs: [(lat: Double, lon: Double)] {
        stride(from: 0, to: routeCoordinates.count - 1, by: 2).map {
            (routeCoordinates[$0], routeCoordinates[$0 + 1])
        }
    }
}
