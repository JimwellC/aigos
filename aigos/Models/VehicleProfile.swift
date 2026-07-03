//
//  VehicleProfile.swift
//  aigos
//
//  A user's vehicle. Each vehicle links to its own DrivingProfile so estimates
//  adapt to how that specific vehicle is driven (Section 9).
//

import Foundation
import SwiftData

@Model
final class VehicleProfile {
    var id: UUID = UUID()
    var name: String = ""            // e.g. "My Vios", "Delivery Bike"
    var type: VehicleType = VehicleType.car
    var fuelType: FuelType = FuelType.premium95
    var efficiencyKmL: Double = 12.0 // manufacturer km/L rating
    var isDefault: Bool = false
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade)
    var drivingProfile: DrivingProfile?

    init(
        name: String,
        type: VehicleType,
        fuelType: FuelType,
        efficiencyKmL: Double,
        isDefault: Bool = false,
        drivingProfile: DrivingProfile? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.fuelType = fuelType
        self.efficiencyKmL = efficiencyKmL
        self.isDefault = isDefault
        self.createdAt = Date()
        self.drivingProfile = drivingProfile
    }
}
