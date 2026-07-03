//
//  Enums.swift
//  aigos
//
//  Shared domain enums (Section 9). All are String-backed and Codable so they
//  can be stored directly on SwiftData @Model entities.
//

import Foundation
import SwiftUI

enum VehicleType: String, Codable, CaseIterable, Identifiable {
    case car, motorcycle, truck, van

    var id: String { rawValue }

    var label: String {
        switch self {
        case .car: "Car"
        case .motorcycle: "Motorcycle"
        case .truck: "Truck"
        case .van: "Van"
        }
    }

    var systemImage: String {
        switch self {
        case .car: "car.fill"
        case .motorcycle: "bicycle"
        case .truck: "truck.box.fill"
        case .van: "van.fill"
        }
    }

    /// Typical fuel-tank capacity (litres) used to estimate the low-fuel warning.
    var typicalTankLiters: Double {
        switch self {
        case .car: 45
        case .motorcycle: 6
        case .truck: 100
        case .van: 65
        }
    }
}

enum FuelType: String, Codable, CaseIterable, Identifiable {
    case ron91, ron95, ron97, diesel

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ron91: "RON 91"
        case .ron95: "RON 95"
        case .ron97: "RON 97"
        case .diesel: "Diesel"
        }
    }

    /// PH pump prices (PHP/L) used to seed the price cache on first launch.
    /// Sourced from fuelprice.ph (DOE) for the week of Jun 30 – Jul 6, 2026;
    /// users can override any price in the Prices tab (Section 9).
    var seedPrice: Double {
        switch self {
        case .ron91: 72.00
        case .ron95: 73.00
        case .ron97: 76.00
        case .diesel: 69.10
        }
    }

    /// Per-grade accent colour for the Prices screen left border.
    var accentColor: Color {
        switch self {
        case .ron91: Color(hex: "#7ED957")   // green
        case .ron95: Color(hex: "#5AA9E6")   // blue
        case .ron97: Color(hex: "#B57EDC")   // purple
        case .diesel: Color(hex: "#F2994A")  // orange
        }
    }
}

enum RoadType: String, Codable, CaseIterable, Identifiable {
    case highway, city, mountain

    var id: String { rawValue }

    var label: String {
        switch self {
        case .highway: "Highway"
        case .city: "City"
        case .mountain: "Mountain"
        }
    }

    /// Road-type fuel multiplier (Section 8).
    var factor: Double {
        switch self {
        case .highway: 1.00   // baseline
        case .city: 1.20      // stop-and-go +20%
        case .mountain: 1.35  // elevation changes +35%
        }
    }
}

enum ProfileConfidence: String, Codable {
    case new        // 0–4 trips
    case building   // 5–14 trips
    case confident  // 15+ trips

    /// Result-screen label reflecting how much history backs the estimate.
    var label: String {
        switch self {
        case .new: "Learning your style…"
        case .building: "Getting to know you"
        case .confident: "Based on your history"
        }
    }
}

/// Per-trip traffic condition. EDSA-at-rush-hour is "standstill".
enum TrafficCondition: String, Codable, CaseIterable, Identifiable {
    case light, moderate, heavy, standstill

    var id: String { rawValue }

    var label: String {
        switch self {
        case .light: "Light"
        case .moderate: "Moderate"
        case .heavy: "Heavy"
        case .standstill: "Standstill"
        }
    }

    /// Fuel multiplier — stop-and-go and idling burn more.
    var factor: Double {
        switch self {
        case .light: 1.00
        case .moderate: 1.08
        case .heavy: 1.25
        case .standstill: 1.35
        }
    }
}

/// How heavily the vehicle is loaded — more weight, more fuel.
enum VehicleLoad: String, Codable, CaseIterable, Identifiable {
    case light, moderate, full, cargo

    var id: String { rawValue }

    var label: String {
        switch self {
        case .light: "Driver only"
        case .moderate: "3–4 pax"
        case .full: "Full load"
        case .cargo: "With cargo"
        }
    }

    var factor: Double {
        switch self {
        case .light: 1.00
        case .moderate: 1.05
        case .full: 1.10
        case .cargo: 1.15
        }
    }
}

/// Current fuel-tank level, used only for the low-fuel warning (not the cost).
enum FuelLevel: String, Codable, CaseIterable, Identifiable {
    case full, threeQuarters, half, quarter, low

    var id: String { rawValue }

    var label: String {
        switch self {
        case .full: "Full"
        case .threeQuarters: "3/4"
        case .half: "Half"
        case .quarter: "1/4"
        case .low: "Low"
        }
    }

    /// Fraction of tank capacity assumed remaining.
    var fraction: Double {
        switch self {
        case .full: 1.0
        case .threeQuarters: 0.75
        case .half: 0.5
        case .quarter: 0.25
        case .low: 0.10
        }
    }
}
