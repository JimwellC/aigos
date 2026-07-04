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
    /// Fuel-tank capacity in litres. Auto-filled from the vehicle database when a
    /// model is picked, editable in Add/Edit. 45 L is the unknown-vehicle fallback
    /// (a typical compact-car tank; matches `VehicleType.car.typicalTankLiters`).
    var tankCapacityL: Double = 45.0
    var isDefault: Bool = false
    var createdAt: Date = Date()

    /// Model/manufacturing year (optional). When set, an age efficiency modifier
    /// is applied based on typical engine wear.
    var manufacturingYear: Int? = nil
    /// Maintenance status — an efficiency modifier (recent PMS +5%, overdue −15%).
    var maintenanceStatus: MaintenanceStatus = MaintenanceStatus.average

    // Bidirectional to-one: the `inverse:` makes SwiftData manage both sides, which
    // it needs to serialize the relationship safely on the persistent store. The
    // previous no-inverse version crashed with swift_dynamicCastFailure inside
    // SwiftData's save() on device (iPhone 11 / iOS 26) — see DrivingProfile.vehicle.
    @Relationship(deleteRule: .cascade, inverse: \DrivingProfile.vehicle)
    var drivingProfile: DrivingProfile?

    init(
        name: String,
        type: VehicleType,
        fuelType: FuelType,
        efficiencyKmL: Double,
        tankCapacityL: Double = 45.0,
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
        self.tankCapacityL = tankCapacityL
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

extension VehicleProfile {
    /// Atomically make `vehicle` the one-and-only default vehicle.
    ///
    /// The single safe path for changing the default from anywhere (garage,
    /// Settings, Add/Edit). It fetches every persisted vehicle from the
    /// `ModelContext` — the source of truth, not a possibly-stale or filtered
    /// `@Query` snapshot — clears all their `isDefault` flags, sets this one's,
    /// and saves **once**. SwiftData errors are caught and logged rather than
    /// allowed to propagate into a crash (P0 hardening).
    ///
    /// Returns `true` when the change persisted, `false` when a SwiftData error
    /// was caught (callers can ignore the result; state stays consistent).
    @MainActor
    @discardableResult
    static func setAsDefault(_ vehicle: VehicleProfile, context: ModelContext) -> Bool {
        do {
            let all = try context.fetch(FetchDescriptor<VehicleProfile>())
            for v in all { v.isDefault = (v.id == vehicle.id) }
            // Guarantee the target ends up default even if it isn't in the fetch
            // yet (e.g. just inserted in this run loop and not persisted).
            vehicle.isDefault = true
            try context.save()
            return true
        } catch {
            #if DEBUG
            print("⚠️ VehicleProfile.setAsDefault failed: \(error)")
            #endif
            return false
        }
    }
}
