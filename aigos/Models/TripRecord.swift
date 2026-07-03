//
//  TripRecord.swift
//  aigos
//
//  A snapshot of one calculation, auto-saved on every calculate. Stores the full
//  breakdown (each adjustment factor, price at the time) so History can show an
//  honest, reproducible record and feed the self-learning profile (Section 9).
//

import Foundation
import SwiftData

@Model
final class TripRecord {
    var id: UUID = UUID()
    var origin: String = ""
    var destination: String = ""
    var distanceKm: Double = 0

    var baseLitres: Double = 0          // litres at manufacturer rating
    var adjustedLitres: Double = 0      // litres after driving-profile factors

    var speedFactor: Double = 1.0       // e.g. 1.13
    var acFactor: Double = 1.0          // 1.12 or 1.0
    var roadFactor: Double = 1.0        // 1.00, 1.20, or 1.35

    var fuelPriceAtTime: Double = 0     // snapshot when calculated
    var totalCostPHP: Double = 0

    var vehicleName: String = ""        // snapshot
    var fuelType: FuelType = FuelType.ron95
    var avgHighwaySpeed: Double = 0
    var avgCitySpeed: Double = 0
    var roadType: RoadType = RoadType.highway
    var acWasOn: Bool = false

    var calculatedAt: Date = Date()
    var isFavorite: Bool = false

    init(
        origin: String,
        destination: String,
        vehicleName: String,
        fuelType: FuelType,
        estimate: FuelEstimate,
        avgHighwaySpeed: Double,
        avgCitySpeed: Double,
        roadType: RoadType,
        acWasOn: Bool
    ) {
        self.id = UUID()
        self.origin = origin
        self.destination = destination
        self.distanceKm = estimate.distanceKm
        self.baseLitres = estimate.baseLitres
        self.adjustedLitres = estimate.adjustedLitres
        self.speedFactor = estimate.speedFactor
        self.acFactor = estimate.acFactor
        self.roadFactor = estimate.roadFactor
        self.fuelPriceAtTime = estimate.fuelPricePerLitre
        self.totalCostPHP = estimate.estimatedCost
        self.vehicleName = vehicleName
        self.fuelType = fuelType
        self.avgHighwaySpeed = avgHighwaySpeed
        self.avgCitySpeed = avgCitySpeed
        self.roadType = roadType
        self.acWasOn = acWasOn
        self.calculatedAt = Date()
    }
}
