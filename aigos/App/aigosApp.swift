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
        // Capture a best-effort stack for any crash so build 60/61's device-only
        // crashes surface a cause (the OS/TestFlight report stays the source of
        // truth — handlers re-raise to preserve it).
        CrashReporter.install()

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
            // A persistent-store failure (e.g. a migration/format issue on a new OS)
            // must NOT hard-crash at launch. Log the cause, then fall back to an
            // in-memory container so the app still opens and the user can retry.
            CrashReporter.record("ModelContainer(persistent) failed: \(error)")
            do {
                let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                container = try ModelContainer(for: schema, configurations: [memory])
            } catch {
                fatalError("Could not create ModelContainer (even in-memory): \(error)")
            }
        }

        #if DEBUG
        if DebugSupport.isSeedDemo {
            DebugSupport.seed(container.mainContext)
        } else if DebugSupport.isSeedEmpty {
            DebugSupport.seedEmpty(container.mainContext)
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
