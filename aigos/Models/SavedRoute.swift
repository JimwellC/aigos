//
//  SavedRoute.swift
//  aigos
//
//  A named route the user starred for one-tap recalculation with today's prices
//  and current driving profile (Section 9). Fully wired in Sprint 2.
//

import Foundation
import SwiftData

@Model
final class SavedRoute {
    var id: UUID = UUID()
    var name: String = ""            // user label, e.g. "Home to Office"
    var origin: String = ""
    var destination: String = ""
    var distanceKm: Double = 0
    var defaultVehicleId: UUID?      // optional preferred vehicle for this route
    var savedAt: Date = Date()

    init(
        name: String,
        origin: String,
        destination: String,
        distanceKm: Double,
        defaultVehicleId: UUID? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.origin = origin
        self.destination = destination
        self.distanceKm = distanceKm
        self.defaultVehicleId = defaultVehicleId
        self.savedAt = Date()
    }
}
