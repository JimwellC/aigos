//
//  FuelLog.swift
//  aigos
//
//  A logged gas-up (v1.1). Two or more full-tank logs with odometer readings let
//  aigos compute the vehicle's REAL fill-to-fill km/L and feed the monthly report.
//  Local-only, like everything else.
//

import Foundation
import SwiftData

@Model
final class FuelLog {
    var id: UUID = UUID()
    var date: Date = Date()
    var vehicleId: UUID = UUID()
    var vehicleName: String = ""
    var stationName: String?
    var fuelType: FuelType = FuelType.premium95
    var litersPurchased: Double = 0
    var totalCostPHP: Double = 0
    var pricePerLiter: Double = 0
    var odometerKm: Double?
    var isFullTank: Bool = true
    var notes: String?
    var createdAt: Date = Date()

    init(
        date: Date = Date(),
        vehicleId: UUID,
        vehicleName: String,
        fuelType: FuelType,
        litersPurchased: Double,
        totalCostPHP: Double,
        pricePerLiter: Double,
        odometerKm: Double? = nil,
        isFullTank: Bool = true,
        stationName: String? = nil,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.vehicleId = vehicleId
        self.vehicleName = vehicleName
        self.fuelType = fuelType
        self.litersPurchased = litersPurchased
        self.totalCostPHP = totalCostPHP
        self.pricePerLiter = pricePerLiter
        self.odometerKm = odometerKm
        self.isFullTank = isFullTank
        self.stationName = stationName
        self.notes = notes
        self.createdAt = Date()
    }
}
