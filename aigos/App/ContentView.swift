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

    var body: some View {
        currentScreen
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                AigosTabBar(selected: $appState.selectedTab)
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
    }

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
                    Haptics.tap(.light)
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
