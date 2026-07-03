//
//  HistoryView.swift
//  aigos
//
//  Auto-saved trip log (Tab 2). Sprint 1 shows a basic list of saved trips;
//  month-over-month comparison and the self-learning hook arrive in Sprint 2.
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TripRecord.calculatedAt, order: .reverse) private var trips: [TripRecord]

    var body: some View {
        NavigationStack {
            List {
                ForEach(trips) { trip in
                    TripRowView(trip: trip)
                }
                .onDelete(perform: delete)
            }
            .navigationTitle("History")
            .overlay {
                if trips.isEmpty {
                    ContentUnavailableView(
                        "No trips yet",
                        systemImage: "clock",
                        description: Text("Your calculations are saved here automatically.")
                    )
                }
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { context.delete(trips[index]) }
        try? context.save()
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: [
            VehicleProfile.self, DrivingProfile.self, TripRecord.self,
            SavedRoute.self, FuelPriceCache.self,
        ], inMemory: true)
}
