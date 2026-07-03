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
            AigosBackground(deep: true)

            if routes.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.md) {
                        Text("SAVED")
                            .rounded(30, weight: .bold)
                            .kerning(1.5)
                            .foregroundStyle(.white)
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
                    .foregroundStyle(Color.aigosAmber)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(route.name)
                        .rounded(16, weight: .semibold)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("\(route.distanceKm.oneDecimal) km")
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
        VStack(spacing: Space.md) {
            Image(systemName: "star.slash")
                .font(.system(size: 52))
                .foregroundStyle(.white.opacity(0.8))
            Text("No saved routes")
                .rounded(22, weight: .semibold)
                .foregroundStyle(.white)
            Text("Tap “Save this route” after a calculation to keep it here for one-tap recalculation.")
                .rounded(15)
                .foregroundStyle(Color.aigosTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Space.xl)
    }

    private func recalculate(_ route: SavedRoute) {
        Haptics.tap(.medium)
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
        ], inMemory: true)
}
