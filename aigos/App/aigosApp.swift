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
            ContentView()
        }
        .modelContainer(container)
    }
}
