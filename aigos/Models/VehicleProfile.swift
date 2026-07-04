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

    /// Model/manufacturing year (optional). When set, an age efficiency modifier
    /// is applied based on typical engine wear.
    var manufacturingYear: Int? = nil
    /// Maintenance status — an efficiency modifier (recent PMS +5%, overdue −15%).
    var maintenanceStatus: MaintenanceStatus = MaintenanceStatus.average

    @Relationship(deleteRule: .cascade)
    var drivingProfile: DrivingProfile?

    init(
        name: String,
        type: VehicleType,
        fuelType: FuelType,
        efficiencyKmL: Double,
        isDefault: Bool = false,
        manufacturingYear: Int? = nil,
        maintenanceStatus: MaintenanceStatus = .average,
        drivingProfile: DrivingProfile? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.fuelType = fuelType
        self.efficiencyKmL = efficiencyKmL
        self.isDefault = isDefault
        self.manufacturingYear = manufacturingYear
        self.maintenanceStatus = maintenanceStatus
        self.drivingProfile = drivingProfile
        self.createdAt = Date()
    }

    /// Vehicle age in whole years given "now", or nil when no year is set.
    func ageYears(asOf now: Date = Date()) -> Int? {
        guard let year = manufacturingYear else { return nil }
        let current = Calendar.current.component(.year, from: now)
        return max(0, current - year)
    }
}
