//
//  DrivingProfile.swift
//  aigos
//
//  Per-vehicle driving style — set via the "Talk to aigos" interview and
//  self-corrected over time from trip history (Section 9 / 14). This is aigos's
//  key differentiator: estimates adapt to how YOU actually drive.
//

import Foundation
import SwiftData

@Model
final class DrivingProfile {
    var id: UUID = UUID()
    var vehicleId: UUID = UUID()   // legacy id (kept for back-compat; not read for logic)

    /// The owning vehicle. This is the INVERSE of `VehicleProfile.drivingProfile`,
    /// making the relationship bidirectional so SwiftData manages its backing data
    /// correctly on the persistent store. A one-way (no-inverse) to-one relationship
    /// caused a `swift_dynamicCastFailure` inside SwiftData's save on device
    /// (iPhone 11 / iOS 26) — see the crash-log analysis. Set automatically when
    /// `vehicle.drivingProfile = profile` is assigned.
    var vehicle: VehicleProfile?

    // User-reported (set via Talk to aigos interview)
    var avgHighwaySpeedKmh: Double = 90.0   // default: 90 km/h
    var avgCitySpeedKmh: Double = 40.0      // default: 40 km/h
    var usesACByDefault: Bool = true        // default: true (PH climate)
    var defaultRoadType: RoadType = RoadType.highway

    // Self-correcting fields (updated after each trip)
    var tripCount: Int = 0
    var avgActualHighwaySpeed: Double?      // learned from history
    var avgActualCitySpeed: Double?         // learned from history
    var acUsageRate: Double = 1.0           // fraction of trips with AC on

    // Confidence — low until 5+ trips logged
    var confidenceLevel: ProfileConfidence = ProfileConfidence.new
    var lastUpdated: Date = Date()

    init(vehicleId: UUID) {
        self.id = UUID()
        self.vehicleId = vehicleId
        self.lastUpdated = Date()
    }
}
