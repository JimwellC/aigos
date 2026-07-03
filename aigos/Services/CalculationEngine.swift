//
//  CalculationEngine.swift
//  aigos
//
//  The core physics-based fuel-cost formula (Section 8). Pure and deterministic —
//  no I/O, no state — so it is trivially testable and safe to call from anywhere.
//
//  adjustmentMultiplier = speedFactor * acFactor * roadFactor
//  adjustedEfficiency    = baseEfficiencyKmL / adjustmentMultiplier
//  litresNeeded          = distanceKm / adjustedEfficiency
//  estimatedCost         = litresNeeded * fuelPricePerLitre
//

import Foundation

/// The full breakdown shown to the user — not just a number. Transparency is a
/// core product principle (Section 14D).
struct FuelEstimate: Equatable {
    let distanceKm: Double
    let baseEfficiencyKmL: Double
    let baseLitres: Double

    let speedFactor: Double
    let acFactor: Double
    let roadFactor: Double
    let adjustmentMultiplier: Double

    let adjustedEfficiencyKmL: Double
    let adjustedLitres: Double

    let fuelPricePerLitre: Double
    let estimatedCost: Double

    /// Extra litres attributable to a single factor, holding the others at
    /// baseline — used for the "+0.8 L" annotations in the breakdown.
    func litres(forFactor factor: Double) -> Double {
        baseLitres * (factor - 1.0)
    }
}

enum CalculationEngine {

    /// Speed-factor lookup table (Section 14E). Optimal economy is 80–100 km/h.
    static func speedFactor(forSpeed speed: Double) -> Double {
        switch speed {
        case ..<60: 1.18     // heavy city — stop-and-go, idling
        case 60..<80: 1.08   // light city / suburb
        case 80..<100: 1.00  // peak efficiency zone
        case 100..<120: 1.13 // fast highway — drag rises
        default: 1.22        // very fast — significant drag
        }
    }

    /// The relevant speed for a trip depends on the road type: city trips are
    /// governed by city speed, highway/mountain by highway speed.
    static func relevantSpeed(
        roadType: RoadType,
        highway: Double,
        city: Double
    ) -> Double {
        roadType == .city ? city : highway
    }

    /// Runs the full estimate.
    /// - Parameter baseEfficiencyKmL: manufacturer km/L rating (already converted
    ///   from L/100km if the user is in that mode — see `kmL(fromL100:)`).
    static func estimate(
        distanceKm: Double,
        baseEfficiencyKmL: Double,
        fuelPricePerLitre: Double,
        avgHighwaySpeedKmh: Double,
        avgCitySpeedKmh: Double,
        acInUse: Bool,
        roadType: RoadType
    ) -> FuelEstimate {
        let safeEfficiency = max(baseEfficiencyKmL, 0.1)

        let speed = relevantSpeed(
            roadType: roadType,
            highway: avgHighwaySpeedKmh,
            city: avgCitySpeedKmh
        )
        let speedFactor = speedFactor(forSpeed: speed)
        let acFactor = acInUse ? 1.12 : 1.0
        let roadFactor = roadType.factor

        let multiplier = speedFactor * acFactor * roadFactor
        let adjustedEfficiency = safeEfficiency / multiplier

        let baseLitres = distanceKm / safeEfficiency
        let adjustedLitres = distanceKm / adjustedEfficiency
        let cost = adjustedLitres * fuelPricePerLitre

        return FuelEstimate(
            distanceKm: distanceKm,
            baseEfficiencyKmL: safeEfficiency,
            baseLitres: baseLitres,
            speedFactor: speedFactor,
            acFactor: acFactor,
            roadFactor: roadFactor,
            adjustmentMultiplier: multiplier,
            adjustedEfficiencyKmL: adjustedEfficiency,
            adjustedLitres: adjustedLitres,
            fuelPricePerLitre: fuelPricePerLitre,
            estimatedCost: cost
        )
    }

    /// Convert L/100km to km/L before feeding the formula (Settings toggle).
    static func kmL(fromL100 value: Double) -> Double {
        guard value > 0 else { return 0 }
        return 100.0 / value
    }
}
