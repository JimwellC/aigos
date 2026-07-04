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

/// All data the comparison sheet needs — presented via `.sheet(item:)` so the
/// content is guaranteed non-nil the moment the sheet appears (no first-present
/// race that showed a black sheet).
private struct ComparisonData: Identifiable {
    let id = UUID()
    let summary: TripSummary
    let estDistanceKm: Double
    let estFuelL: Double
    let estCostPHP: Double
    let ratedKmL: Double
    let vehicleName: String
}

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @State private var appState = AppState()
    @AppStorage("hasOnboarded") private var hasOnboarded = false

    // Global GPS-tracking UI (visible on every tab, above the floating tab bar).
    @State private var tracker = TripTracker.shared
    @State private var expanded = false
    @State private var showingEndConfirm = false
    @State private var comparison: ComparisonData?   // non-nil → comparison sheet shows
    @State private var showingTooShort = false

    var body: some View {
        currentScreen
            .id(appState.selectedTab)               // simple crossfade between tabs
            .transition(.opacity)
            .animation(.easeOut(duration: 0.15), value: appState.selectedTab)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Expanded dashboard = a bottom sheet FLOATING over content (doesn't push
            // it, never touches the header). Anchored just above the mini bar / tab bar.
            .overlay(alignment: .bottom) {
                if tracker.isLive && expanded {
                    TrackingExpandedSheet(
                        tracker: tracker,
                        onCollapse: collapse,
                        onEnd: endTracking)
                        .transition(.opacity)   // fade in/out — calm, no slide
                }
            }
            // The compact bar sits in the bottom inset directly above the tab bar —
            // it only reserves ~56pt, so the header is never pushed. It fades in when
            // tracking starts and out when it ends, and stays perfectly still on tab
            // switches (neither isLive nor expanded changes).
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 8) {
                    if tracker.isLive && !expanded {
                        TrackingMiniBar(
                            tracker: tracker,
                            onTap: expand,
                            onLongPressEnd: { showingEndConfirm = true })
                            .transition(.opacity)
                    }
                    AigosTabBar(selected: $appState.selectedTab)
                }
                .animation(.easeOut(duration: 0.2), value: tracker.isLive)
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
            // .sheet(item:) — the data is passed to the closure directly, so it's
            // always present when the sheet renders (fixes the first-end black screen).
            .sheet(item: $comparison) { data in
                TripComparisonView(
                    summary: data.summary,
                    estDistanceKm: data.estDistanceKm, estFuelL: data.estFuelL, estCostPHP: data.estCostPHP,
                    vehicleName: data.vehicleName, ratedKmL: data.ratedKmL,
                    onUpdateProfile: { updateEfficiency($0, vehicleName: data.vehicleName) }, onKeep: {})
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground { AigosBackground() }
            }
            .confirmationDialog("End this trip?", isPresented: $showingEndConfirm, titleVisibility: .visible) {
                Button("End Trip", role: .destructive, action: endTracking)
                Button("Cancel", role: .cancel) {}
            }
            .alert("Trip too short to compare", isPresented: $showingTooShort) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Drive at least 1 km for tracking to give useful results.")
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

    // Expand: ease up (0.25s). Collapse: ease down (0.2s). No spring, no bounce.
    private func expand() { withAnimation(.easeOut(duration: 0.25)) { expanded = true } }
    private func collapse() { withAnimation(.easeOut(duration: 0.2)) { expanded = false } }

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
        let tripId = tracker.tripRecordId
        let origin = tracker.origin, destination = tracker.destination, vname = tracker.vehicleName
        let estDist = tracker.estDistanceKm, estFuel = tracker.estFuelL
        let estCost = tracker.estCostPHP, rated = tracker.ratedKmL

        let summary = tracker.finish()
        Haptics.success()   // End Trip confirmation
        collapse()          // fade the bar out (isLive is now false → bar removes)

        // Too short to compare (tapped Track then End, or no GPS points recorded).
        // Don't save a junk 0-km trip and don't present a blank sheet.
        guard summary.actualDistanceKm >= 0.5 else {
            showingTooShort = true
            return
        }

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

        // Present the comparison. .sheet(item:) → fully-initialized data, no black
        // screen and no dismiss/present race.
        comparison = ComparisonData(
            summary: summary, estDistanceKm: estDist, estFuelL: estFuel,
            estCostPHP: estCost, ratedKmL: rated, vehicleName: vname)
    }

    /// Self-correct the tracked vehicle's efficiency (comparison already clamped it).
    private func updateEfficiency(_ newKmL: Double, vehicleName name: String) {
        let d = FetchDescriptor<VehicleProfile>(predicate: #Predicate { $0.name == name })
        if let v = try? context.fetch(d).first {
            v.efficiencyKmL = newKmL
            v.drivingProfile?.lastUpdated = Date()
            try? context.save()
        }
    }
}

/// Floating pill tab bar — icon-only. The amber indicator circle simply appears
/// under the selected tab (no matched-geometry slide, no bounce — calm and fast).
/// Attached via `.safeAreaInset(.bottom)` so content never hides behind it.
struct AigosTabBar: View {
    @Binding var selected: Tab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { tab in
                Button {
                    selected = tab
                } label: {
                    ZStack {
                        if selected == tab {
                            Circle()
                                .fill(Color.aigosAmber)
                                .frame(width: 44, height: 44)
                        }
                        Image(systemName: tab.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(selected == tab ? .white : .white.opacity(0.45))
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
