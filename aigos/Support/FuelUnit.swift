//
//  FuelUnit.swift
//  aigos
//
//  Fuel-efficiency display unit (Section 6). Vehicles always STORE efficiency in
//  km/L (the canonical unit the CalculationEngine consumes); this enum only maps
//  that canonical value to/from what the user sees and types when the Settings
//  toggle is set to L/100km. Persisted via @AppStorage("fuelUnit").
//

import Foundation

enum FuelUnit: String, CaseIterable, Identifiable {
    case kmPerL
    case lPer100km

    var id: String { rawValue }

    var label: String {
        switch self {
        case .kmPerL: "km/L"
        case .lPer100km: "L/100km"
        }
    }

    /// Canonical km/L → this unit's display value.
    func displayValue(fromKmL kmL: Double) -> Double {
        switch self {
        case .kmPerL: kmL
        case .lPer100km: CalculationEngine.l100(fromKmL: kmL)
        }
    }

    /// A value entered in this unit → canonical km/L for storage.
    func kmL(fromDisplay value: Double) -> Double {
        switch self {
        case .kmPerL: value
        case .lPer100km: CalculationEngine.kmL(fromL100: value)
        }
    }

    /// Formatted efficiency, e.g. "14.5 km/L" or "6.9 L/100km".
    func format(kmL: Double) -> String {
        "\(displayValue(fromKmL: kmL).oneDecimal) \(label)"
    }

    /// A sensible default efficiency for a new vehicle, expressed in this unit
    /// (both defaults describe roughly the same real-world economy).
    var defaultInput: String {
        switch self {
        case .kmPerL: "12"
        case .lPer100km: "8.3"
        }
    }
}
