//
//  AppState.swift
//  aigos
//
//  Lightweight app-wide router shared via the SwiftUI environment. Drives the
//  custom tab bar and carries a pending "recalculate this route" draft so the
//  Saved tab can hand a route to the Calculate tab in one tap.
//

import SwiftUI

enum Tab: Int, CaseIterable, Identifiable {
    case calculate, history, saved, prices, settings

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .calculate: "Calculate"
        case .history: "History"
        case .saved: "Saved"
        case .prices: "Prices"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .calculate: "car.fill"
        case .history: "clock.fill"
        case .saved: "star.fill"
        case .prices: "fuelpump.fill"
        case .settings: "gearshape.fill"
        }
    }
}

/// A route handed from Saved/Talk → Calculate for one-tap recalculation.
/// Optional hints let Talk to aigos preset conditions it understood from a query.
struct CalculatorDraft: Equatable {
    let origin: String
    let destination: String
    let distanceKm: Double
    let vehicleId: UUID?
    var traffic: TrafficCondition? = nil
    var acOn: Bool? = nil
    var rushHour: Bool? = nil
    var load: VehicleLoad? = nil
}

@Observable
final class AppState {
    var selectedTab: Tab = .calculate

    /// Set by SavedRoutesView; consumed by CalculateView which prefills + recalcs.
    var pendingDraft: CalculatorDraft?

    init() {
        #if DEBUG
        if let tab = DebugSupport.initialTab { selectedTab = tab }
        // Only auto-run a sample estimate when explicitly asked (-autoCalc), so
        // -seedDemo alone shows the fresh Calculate screen.
        if DebugSupport.isSeedDemo, selectedTab == .calculate,
           ProcessInfo.processInfo.arguments.contains("-autoCalc") {
            pendingDraft = DebugSupport.demoDraft
        }
        #endif
    }

    /// Route the app to Calculate with a prefilled draft.
    func recalculate(_ draft: CalculatorDraft) {
        pendingDraft = draft
        selectedTab = .calculate
    }
}
