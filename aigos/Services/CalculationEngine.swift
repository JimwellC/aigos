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
    let trafficFactor: Double
    let loadFactor: Double
    let adjustmentMultiplier: Double

    let adjustedEfficiencyKmL: Double
    let adjustedLitres: Double

    let fuelPricePerLitre: Double
    let estimatedCost: Double

    /// Litres available in the tank right now, if a fuel level was supplied.
    let availableFuelLitres: Double?

    /// Extra litres attributable to a single factor, holding the others at
    /// baseline — used for the "+0.8 L" annotations in the breakdown.
    func litres(forFactor factor: Double) -> Double {
        baseLitres * (factor - 1.0)
    }

    /// True when the trip likely needs more fuel than the tank currently holds.
    var needsRefuel: Bool {
        guard let available = availableFuelLitres else { return false }
        return adjustedLitres > available
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
    /// - Parameters:
    ///   - traffic/load: per-trip conditions (default `.light` = no effect, so
    ///     existing callers are unaffected).
    ///   - availableFuelLitres: litres currently in the tank, for the low-fuel
    ///     warning only; pass nil to skip the warning. Does not affect cost.
    static func estimate(
        distanceKm: Double,
        baseEfficiencyKmL: Double,
        fuelPricePerLitre: Double,
        avgHighwaySpeedKmh: Double,
        avgCitySpeedKmh: Double,
        acInUse: Bool,
        roadType: RoadType,
        traffic: TrafficCondition = .light,
        load: VehicleLoad = .light,
        availableFuelLitres: Double? = nil,
        acUsage: ACUsage? = nil       // when set, its 3-state factor overrides acInUse
    ) -> FuelEstimate {
        let safeEfficiency = max(baseEfficiencyKmL, 0.1)

        let speed = relevantSpeed(
            roadType: roadType,
            highway: avgHighwaySpeedKmh,
            city: avgCitySpeedKmh
        )
        let speedFactor = speedFactor(forSpeed: speed)
        let acFactor = acUsage?.acFactor ?? (acInUse ? 1.12 : 1.0)
        let roadFactor = roadType.factor
        let trafficFactor = traffic.factor
        let loadFactor = load.factor

        let multiplier = speedFactor * acFactor * roadFactor * trafficFactor * loadFactor
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
            trafficFactor: trafficFactor,
            loadFactor: loadFactor,
            adjustmentMultiplier: multiplier,
            adjustedEfficiencyKmL: adjustedEfficiency,
            adjustedLitres: adjustedLitres,
            fuelPricePerLitre: fuelPricePerLitre,
            estimatedCost: cost,
            availableFuelLitres: availableFuelLitres
        )
    }

    /// Convert L/100km → km/L before feeding the formula (Settings toggle).
    static func kmL(fromL100 value: Double) -> Double {
        guard value > 0 else { return 0 }
        return 100.0 / value
    }

    /// Convert km/L → L/100km (the Settings display unit). Inverse of
    /// `kmL(fromL100:)`; the two round-trip losslessly for positive values.
    static func l100(fromKmL value: Double) -> Double {
        guard value > 0 else { return 0 }
        return 100.0 / value
    }
}
