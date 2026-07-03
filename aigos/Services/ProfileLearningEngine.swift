//
//  ProfileLearningEngine.swift
//  aigos
//
//  The self-learning engine (Section 14C). After each trip, the vehicle's
//  DrivingProfile updates via a rolling average that weights recent trips most,
//  recomputes the AC-usage rate, and advances the confidence level. This is what
//  makes aigos feel smarter the more it's used.
//

import Foundation

enum ProfileLearningEngine {

    /// Fold one trip into the profile's learned averages.
    static func updateProfile(_ profile: DrivingProfile, with trip: TripRecord) {
        profile.tripCount += 1

        // Rolling average — the last ~10 trips dominate.
        let weight = min(Double(profile.tripCount), 10.0)
        profile.avgActualHighwaySpeed = rollingAvg(
            existing: profile.avgActualHighwaySpeed ?? trip.avgHighwaySpeed,
            new: trip.avgHighwaySpeed,
            weight: weight
        )
        profile.avgActualCitySpeed = rollingAvg(
            existing: profile.avgActualCitySpeed ?? trip.avgCitySpeed,
            new: trip.avgCitySpeed,
            weight: weight
        )

        // AC usage rate — cumulative fraction of trips with AC on.
        let count = Double(profile.tripCount)
        profile.acUsageRate = ((profile.acUsageRate * (count - 1)) + (trip.acWasOn ? 1.0 : 0.0)) / count

        // Confidence level by trip count.
        profile.confidenceLevel = switch profile.tripCount {
        case 0..<5: .new
        case 5..<15: .building
        default: .confident
        }

        profile.lastUpdated = Date()
    }

    /// Weighted rolling average: newer samples pull the mean toward `new`.
    static func rollingAvg(existing: Double, new: Double, weight: Double) -> Double {
        guard weight > 0 else { return new }
        return ((existing * (weight - 1)) + new) / weight
    }
}
