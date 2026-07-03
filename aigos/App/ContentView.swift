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

/// Custom bottom tab bar with the deep amber/brown gradient.
struct AigosTabBar: View {
    @Binding var selected: Tab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { tab in
                Button {
                    Haptics.tap(.light)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { selected = tab }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20))
                        Text(tab.title)
                            .rounded(11, weight: .medium)
                    }
                    .foregroundStyle(selected == tab ? Color.aigosAmber : Color.white.opacity(0.45))
                    .scaleEffect(selected == tab ? 1.12 : 1.0)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(
            LinearGradient(
                colors: [Color.aigosTabTop.opacity(0.96), Color.aigosTabBottom.opacity(0.98)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            VehicleProfile.self, DrivingProfile.self, TripRecord.self,
            SavedRoute.self, FuelPriceCache.self,
            PersonalPlace.self,
        ], inMemory: true)
}
