//
//  Enums.swift
//  aigos
//
//  Shared domain enums (Section 9). All are String-backed and Codable so they
//  can be stored directly on SwiftData @Model entities.
//

import Foundation

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
