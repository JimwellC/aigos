//
//  SavedRoutesView.swift
//  aigos
//
//  Starred routes (Tab 3, Feature 05). Tap a route to recalculate it in one tap
//  with today's price and the current driving profile — the draft is handed to
//  the Calculate tab via AppState.
//

import SwiftUI
import SwiftData

struct SavedRoutesView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query(sort: \SavedRoute.savedAt, order: .reverse) private var routes: [SavedRoute]

    var body: some View {
        ZStack {
            AigosBackground(variant: 2, mascotPeek: CGSize(width: 55, height: -75))

            if routes.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.md) {
                        Text("SAVED").screenTitle()
                            .padding(.bottom, Space.sm)

                        ForEach(Array(routes.enumerated()), id: \.element.id) { i, route in
                            routeCard(route)
                                .staggeredAppear(index: i)
                        }
                    }
                    .padding(.horizontal, Space.screen)
                    .padding(.top, Space.xl)
                    .padding(.bottom, Space.xxl)
                }
            }
        }
    }

    private func routeCard(_ route: SavedRoute) -> some View {
        Button {
            recalculate(route)
        } label: {
            HStack(spacing: Space.md) {
                Image(systemName: "star.fill")
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.aigosAmber.opacity(0.9), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(route.name)
                        .rounded(16, weight: .semibold)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("≈ \(route.distanceKm.oneDecimal) km")
                        .rounded(13)
                        .foregroundStyle(Color.aigosTextSecondary)
                }
                Spacer()
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(Space.md)
            .glassCard()
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) { delete(route) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var emptyState: some View {
        MascotEmptyState(
            title: "No saved routes",
            message: "Star any trip to save it for one-tap recalculation."
        )
    }

    private func recalculate(_ route: SavedRoute) {
        appState.recalculate(CalculatorDraft(
            origin: route.origin,
            destination: route.destination,
            distanceKm: route.distanceKm,
            vehicleId: route.defaultVehicleId
        ))
    }

    private func delete(_ route: SavedRoute) {
        context.delete(route)
        try? context.save()
    }
}

#Preview {
    SavedRoutesView()
        .environment(AppState())
        .modelContainer(for: [
            VehicleProfile.self, DrivingProfile.self, TripRecord.self,
            SavedRoute.self, FuelPriceCache.self,
            PersonalPlace.self,
            TrackedTrip.self,
            FuelLog.self,
        ], inMemory: true)
}
