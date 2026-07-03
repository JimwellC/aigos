//
//  aigosApp.swift
//  aigos — AI-powered fuel trip calculator for Filipino roads.
//
//  @main entry point. Sets up the single, on-device SwiftData ModelContainer
//  that every screen shares. No cloud, no iCloud sync — all data stays on device.
//

import SwiftUI
import SwiftData

@main
struct aigosApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([
            VehicleProfile.self,
            DrivingProfile.self,
            TripRecord.self,
            SavedRoute.self,
            FuelPriceCache.self,
            PersonalPlace.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }

        #if DEBUG
        if DebugSupport.isSeedDemo {
            DebugSupport.seed(container.mainContext)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}

/// Shows the animated splash, then fades into the main app.
struct RootView: View {
    @State private var showSplash = true

    init() {
        #if DEBUG
        if DebugSupport.forceOnboarding { _showSplash = State(initialValue: false) }
        #endif
    }

    var body: some View {
        ZStack {
            if showSplash {
                SplashView {
                    withAnimation(.easeInOut(duration: 0.45)) { showSplash = false }
                }
                .transition(.opacity)
            } else {
                ContentView()
                    .transition(.opacity)
            }
        }
    }
}
