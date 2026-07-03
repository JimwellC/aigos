//
//  ContentView.swift
//  aigos
//
//  Root TabView — 5 flat tabs, no deep navigation stacks. Every feature is one
//  tap from anywhere (Section 11 of the architecture spec).
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context

    var body: some View {
        TabView {
            CalculateView()
                .tabItem { Label("Calculate", systemImage: "car.fill") }

            HistoryView()
                .tabItem { Label("History", systemImage: "clock.fill") }

            SavedRoutesView()
                .tabItem { Label("Saved", systemImage: "star.fill") }

            PricesView()
                .tabItem { Label("Prices", systemImage: "fuelpump.fill") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(.aigosAmber)
        .task {
            // Seed fuel prices + a sample vehicle on first launch so the
            // calculator works immediately (onboarding replaces this in Sprint 2).
            AppSeeder.seedIfNeeded(context)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            VehicleProfile.self, DrivingProfile.self, TripRecord.self,
            SavedRoute.self, FuelPriceCache.self,
        ], inMemory: true)
}
