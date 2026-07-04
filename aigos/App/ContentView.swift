//
//  ContentView.swift
//  aigos
//
//  Root shell. A custom amber/brown tab bar (no default iOS tab bar, per the
//  design guidelines) drives five flat screens via AppState. Onboarding is
//  presented full-screen on first launch.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @State private var appState = AppState()
    @AppStorage("hasOnboarded") private var hasOnboarded = false

    // Global GPS-tracking UI (visible on every tab, above the floating tab bar).
    @State private var tracker = TripTracker.shared
    @State private var expanded = false
    @State private var showingEndConfirm = false
    @State private var showingComparison = false
    @State private var lastSummary: TripSummary?
    // Estimate context captured at end time, for the comparison sheet.
    @State private var compEstDistance = 0.0
    @State private var compEstFuel = 0.0
    @State private var compEstCost = 0.0
    @State private var compRatedKmL = 0.0
    @State private var compVehicleName = ""

    var body: some View {
        currentScreen
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Expanded dashboard = a bottom sheet FLOATING over content (doesn't push
            // it, never touches the header). Anchored just above the mini bar / tab bar.
            .overlay(alignment: .bottom) {
                if tracker.isLive && expanded {
                    TrackingExpandedSheet(
                        tracker: tracker,
                        onCollapse: collapse,
                        onEnd: endTracking)
                        // Expand: spring up. Collapse: ease down (driven by withAnimation).
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            // The compact bar sits in the bottom inset directly above the tab bar —
            // it only reserves ~56pt, so the header is never pushed. It slides up when
            // tracking starts and down when it ends; it stays perfectly still (no
            // animation) on tab switches, since neither isLive nor expanded changes.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 8) {
                    if tracker.isLive && !expanded {
                        TrackingMiniBar(
                            tracker: tracker,
                            onTap: expand,
                            onLongPressEnd: { showingEndConfirm = true })
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    AigosTabBar(selected: $appState.selectedTab)
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: tracker.isLive)
            }
            .environment(appState)
            .task {
                AppSeeder.seedPricesIfNeeded(context)
                AppSeeder.seedPersonalPlacesIfNeeded(context)
                AppSeeder.normalizeTankCapacitiesIfNeeded(context)
            }
            .fullScreenCover(isPresented: Binding(
                get: { !hasOnboarded },
                set: { _ in }
            )) {
                OnboardingView(hasOnboarded: $hasOnboarded)
            }
            .sheet(isPresented: $showingComparison) {
                if let s = lastSummary {
                    TripComparisonView(
                        summary: s,
                        estDistanceKm: compEstDistance, estFuelL: compEstFuel, estCostPHP: compEstCost,
                        vehicleName: compVehicleName, ratedKmL: compRatedKmL,
                        onUpdateProfile: updateEfficiency, onKeep: {})
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                        .presentationBackground { AigosBackground() }
                }
            }
            .confirmationDialog("End this trip?", isPresented: $showingEndConfirm, titleVisibility: .visible) {
                Button("End Trip", role: .destructive, action: endTracking)
                Button("Cancel", role: .cancel) {}
            }
            // Tracking always starts MINIMIZED — the full dashboard only appears when
            // the user taps the bar. Reset on end, and minimize when switching tabs.
            .onChange(of: tracker.isLive) { _, live in
                if !live { collapse() }
            }
            .onChange(of: appState.selectedTab) { _, _ in
                if expanded { collapse() }
            }
    }

    // Minimize → Expand: spring up. Expand → Minimize: ease down.
    private func expand() { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { expanded = true } }
    private func collapse() { withAnimation(.easeOut(duration: 0.25)) { expanded = false } }

    @ViewBuilder
    private var currentScreen: some View {
        switch appState.selectedTab {
        case .calculate: CalculateView()
        case .history: HistoryView()
        case .saved: SavedRoutesView()
        case .prices: PricesView()
        case .settings: SettingsView()
        }
    }

    // MARK: - End tracking (works from any tab)

    private func endTracking() {
        guard tracker.isLive else { return }
        // Capture the estimate context for the comparison before finishing.
        compEstDistance = tracker.estDistanceKm
        compEstFuel = tracker.estFuelL
        compEstCost = tracker.estCostPHP
        compRatedKmL = tracker.ratedKmL
        compVehicleName = tracker.vehicleName
        let tripId = tracker.tripRecordId
        let origin = tracker.origin, destination = tracker.destination, vname = tracker.vehicleName
        let estDist = tracker.estDistanceKm, estFuel = tracker.estFuelL, estCost = tracker.estCostPHP

        let summary = tracker.finish()
        Haptics.success()   // End Trip confirmation

        let tracked = TrackedTrip(
            tripRecordId: tripId ?? UUID(), estimatedDistanceKm: estDist,
            estimatedFuelL: estFuel, estimatedCostPHP: estCost,
            vehicleName: vname, origin: origin, destination: destination)
        tracked.routeCoordinates = summary.routeFlat
        tracked.actualDistanceKm = summary.actualDistanceKm
        tracked.actualDurationSeconds = summary.actualDurationSeconds
        tracked.actualAvgSpeedKmh = summary.actualAvgSpeedKmh
        tracked.actualFuelL = summary.actualFuelL
        tracked.actualCostPHP = summary.actualCostPHP
        tracked.accuracyPercent = summary.accuracyPercent
        tracked.startedAt = summary.startedAt
        tracked.endedAt = summary.endedAt
        tracked.isCompleted = true
        context.insert(tracked)

        if let tripId {
            let d = FetchDescriptor<TripRecord>(predicate: #Predicate { $0.id == tripId })
            if let trip = try? context.fetch(d).first { trip.isTracked = true }
        }
        try? context.save()

        // Collapse the bar, then present the comparison as a bottom sheet next
        // runloop so the two animations read as one connected motion rather than a
        // dismiss fighting a present.
        collapse()
        lastSummary = summary
        DispatchQueue.main.async { showingComparison = true }
    }

    /// Self-correct the tracked vehicle's efficiency (comparison already clamped it).
    private func updateEfficiency(_ newKmL: Double) {
        let name = compVehicleName
        let d = FetchDescriptor<VehicleProfile>(predicate: #Predicate { $0.name == name })
        if let v = try? context.fetch(d).first {
            v.efficiencyKmL = newKmL
            v.drivingProfile?.lastUpdated = Date()
            try? context.save()
        }
    }
}

/// Floating pill tab bar — icon-only, with an amber indicator circle that springs
/// between tabs. Attached via `.safeAreaInset(.bottom)` so content never hides
/// behind it.
struct AigosTabBar: View {
    @Binding var selected: Tab
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selected = tab }
                } label: {
                    ZStack {
                        if selected == tab {
                            Circle()
                                .fill(Color.aigosAmber)
                                .frame(width: 44, height: 44)
                                .matchedGeometryEffect(id: "tabIndicator", in: ns)
                        }
                        Image(systemName: tab.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(selected == tab ? .white : .white.opacity(0.45))
                            .symbolEffect(.bounce, value: selected == tab)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 64)
        .background {
            ZStack {
                Capsule().fill(.ultraThinMaterial)
                Capsule().fill(Color(hex: "#2C1A0E").opacity(0.92))
            }
        }
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 8)
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            VehicleProfile.self, DrivingProfile.self, TripRecord.self,
            SavedRoute.self, FuelPriceCache.self,
            PersonalPlace.self,
            TrackedTrip.self,
            FuelLog.self,
        ], inMemory: true)
}
