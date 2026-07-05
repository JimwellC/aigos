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

    // MARK: - GPS quality gating (pure — the delegate feeds it raw CLLocation values)

    /// Maximum horizontal accuracy (metres) we'll trust for a route point. Points
    /// with a coarser fix — or an invalid negative one — are dropped.
    static let maxHorizontalAccuracyM: Double = 50

    /// Whether a single GPS fix is good enough to add to the route:
    /// a valid (non-negative) horizontal accuracy under 50 m, and a non-negative
    /// speed (CoreLocation reports -1 when speed can't be determined).
    static func acceptGPSPoint(horizontalAccuracy: Double, speedMetersPerSec: Double) -> Bool {
        guard horizontalAccuracy.isFinite, horizontalAccuracy >= 0,
              horizontalAccuracy < maxHorizontalAccuracyM else { return false }
        guard speedMetersPerSec >= 0 else { return false }
        return true
    }

    /// Whether a leg between two consecutive fixes is physically plausible — used to
    /// discard GPS "teleports". A jump of 500 m or more within ~1 second, or any
    /// leg implying > 100 m/s (~360 km/h), is treated as noise and dropped.
    static func isPlausibleSegment(meters: Double, seconds: Double) -> Bool {
        guard meters.isFinite, meters >= 0 else { return false }
        if seconds <= 1.0 && meters >= 500 { return false }
        if seconds > 0 && meters / seconds > 100 { return false }
        return true
    }

    // MARK: - Trip-quality thresholds (pure — drive the end-of-trip messaging)

    /// Under this distance (km) a comparison is dominated by GPS noise, so we show
    /// guidance instead of an accuracy percentage.
    static let shortTripKm: Double = 3
    /// Minimum tracking duration (s) before a trip is worth measuring at all.
    static let minTrackingSeconds = 30

    static func isShortTrip(distanceKm: Double) -> Bool { distanceKm < shortTripKm }

    static func isTrackingLongEnough(seconds: Int) -> Bool { seconds >= minTrackingSeconds }

    /// The short-trip guidance shown in place of the accuracy percentage.
    static func shortTripMessage(distanceKm: Double) -> String {
        "Short trip detected (\(String(format: "%.1f", distanceKm)) km). GPS accuracy improves on longer drives (5+ km recommended for meaningful comparison)."
    }

    /// A human-friendly interpretation of the accuracy percentage.
    static func accuracyContext(percent: Double) -> String {
        switch percent {
        case 90...:      return "🎯 Very accurate estimate!"
        case 75..<90:    return "👍 Good estimate"
        case 50..<75:    return "📊 Moderate — factors like traffic and detours affected this"
        default:         return "📍 Large difference — this may be due to GPS signal, detours, or a very short trip"
        }
    }

    /// Whether we should offer to update the vehicle profile from this trip. A trip
    /// that's both inaccurate (< 70%) and short (< 5 km) is too unreliable to learn
    /// from, so we suppress the suggestion.
    static func shouldSuggestProfileUpdate(accuracyPercent: Double, distanceKm: Double) -> Bool {
        !(accuracyPercent < 70 && distanceKm < 5)
    }
}
