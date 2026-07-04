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
            TrackedTrip.self,
            FuelLog.self,
        ])
        container = Self.makeContainer(for: schema)

        #if DEBUG
        if DebugSupport.isSeedDemo {
            DebugSupport.seed(container.mainContext)
        } else if DebugSupport.isSeedEmpty {
            DebugSupport.seedEmpty(container.mainContext)
        }
        #endif
    }

    /// Open the on-disk store, recovering from an unopenable one instead of looping
    /// forever in a volatile in-memory store. If the store can't be opened (e.g. a
    /// schema migration this version can't perform), DELETE it, reset onboarding,
    /// and recreate a clean persistent store — a one-time reset the user recovers
    /// from by re-onboarding, rather than permanent, silent data loss on every
    /// launch. v1.0 App Store users are all fresh installs, so this only guards
    /// future updates.
    private static func makeContainer(for schema: Schema) -> ModelContainer {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            CrashReporter.record("ModelContainer(persistent) failed — resetting store: \(error)")
            destroyStore(at: config.url)
            UserDefaults.standard.set(false, forKey: "hasOnboarded")   // re-run onboarding on the clean store
            if let fresh = try? ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)]) {
                return fresh
            }
            // Absolute last resort so the app still opens (should be unreachable now
            // that the on-disk store was cleared).
            CrashReporter.record("ModelContainer still failing after store reset — using in-memory")
            if let memory = try? ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]) {
                return memory
            }
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    /// Delete a SwiftData store file and its SQLite sidecars (-wal, -shm).
    private static func destroyStore(at url: URL) {
        let fm = FileManager.default
        for path in [url.path, url.path + "-wal", url.path + "-shm"] {
            try? fm.removeItem(atPath: path)
        }
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
