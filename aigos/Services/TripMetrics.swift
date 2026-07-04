//
//  TripMetrics.swift
//  aigos
//
//  Pure math for GPS trip tracking + fuel logging (v1.1). No I/O, no location
//  hardware — trivially testable. Actual fuel/cost are DERIVED from the GPS
//  distance and the vehicle's efficiency (aigos has no fuel-flow sensor), so the
//  "accuracy" really measures how close the distance estimate was.
//

import Foundation

enum TripMetrics {

    /// Total distance (km) along a GPS track — the sum of haversine segments.
    static func distanceKm(coordinates: [(lat: Double, lon: Double)]) -> Double {
        guard coordinates.count >= 2 else { return 0 }
        var total = 0.0
        for i in 1..<coordinates.count {
            let a = GeoPoint(lat: coordinates[i - 1].lat, lon: coordinates[i - 1].lon)
            let b = GeoPoint(lat: coordinates[i].lat, lon: coordinates[i].lon)
            let d = GazetteerRouteResolver.haversineKm(a, b)
            if d.isFinite { total += d }
        }
        return total
    }

    /// How close the estimate was, 0–100 (symmetric ratio; 100 = identical).
    static func accuracyPercent(estimated: Double, actual: Double) -> Double {
        guard estimated > 0, actual > 0 else { return 0 }
        return (min(estimated, actual) / max(estimated, actual)) * 100
    }

    /// Litres for a distance at a given efficiency.
    static func fuelLitres(distanceKm: Double, efficiencyKmL: Double) -> Double {
        guard efficiencyKmL > 0, distanceKm.isFinite else { return 0 }
        return distanceKm / efficiencyKmL
    }

    /// Real fill-to-fill km/L: kilometres between two full-tank fill-ups divided by
    /// the litres added at the second fill-up. Nil if the inputs don't make sense.
    static func actualKmL(odometerStart: Double, odometerEnd: Double, litresAtEnd: Double) -> Double? {
        let dist = odometerEnd - odometerStart
        guard dist > 0, litresAtEnd > 0 else { return nil }
        return dist / litresAtEnd
    }

    /// Suggested efficiency after a measurement — a weighted blend of the rated and
    /// measured values (leans toward measured by default, but never wild).
    static func blendedEfficiency(rated: Double, measured: Double, measuredWeight: Double = 0.6) -> Double {
        guard measured > 0 else { return rated }
        let w = min(max(measuredWeight, 0), 1)
        return rated * (1 - w) + measured * w
    }

    /// Current average speed (km/h) from distance so far and elapsed seconds.
    static func avgSpeedKmh(distanceKm: Double, seconds: Int) -> Double {
        guard seconds > 0 else { return 0 }
        return distanceKm / (Double(seconds) / 3600.0)
    }
}
