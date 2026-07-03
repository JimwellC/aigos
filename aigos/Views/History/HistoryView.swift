//
//  HistoryView.swift
//  aigos
//
//  Auto-saved trip log (Tab 2) with month-over-month comparison. Trips are grouped
//  into month sections; a summary card shows this month's total spend and the
//  delta versus last month. History also feeds the self-learning profile.
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TripRecord.calculatedAt, order: .reverse) private var trips: [TripRecord]

    private var months: [MonthGroup] { MonthGroup.group(trips) }

    var body: some View {
        ZStack {
            AigosBackground(deep: true)

            if trips.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.lg) {
                        Text("HISTORY")
                            .rounded(30, weight: .bold)
                            .kerning(1.5)
                            .foregroundStyle(.white)

                        summaryCard

                        ForEach(months) { group in
                            VStack(alignment: .leading, spacing: Space.sm) {
                                Text(group.title.uppercased())
                                    .rounded(13, weight: .semibold)
                                    .kerning(1.2)
                                    .foregroundStyle(Color.aigosTextTertiary)

                                ForEach(group.trips) { trip in
                                    TripRowView(trip: trip)
                                        .contextMenu {
                                            Button(role: .destructive) { delete(trip) } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Space.screen)
                    .padding(.top, Space.xl)
                    .padding(.bottom, Space.xxl)
                }
            }
        }
    }

    private var summaryCard: some View {
        let this = MonthGroup.total(trips, monthsAgo: 0)
        let last = MonthGroup.total(trips, monthsAgo: 1)
        let delta = this - last
        let hasLast = last > 0

        return VStack(alignment: .leading, spacing: Space.sm) {
            Text("THIS MONTH")
                .rounded(12, weight: .medium)
                .kerning(1.5)
                .foregroundStyle(Color.aigosTextSecondary)
            Text(this.phpString)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            if hasLast {
                HStack(spacing: 6) {
                    Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                    Text("\(abs(delta).phpString) vs last month")
                        .rounded(14, weight: .medium)
                }
                .foregroundStyle(delta >= 0 ? Color.aigosAmber : Color(hex: "#8FE39B"))
            } else {
                Text("Your spending trend appears once you have a prior month.")
                    .rounded(13)
                    .foregroundStyle(Color.aigosTextTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.lg)
        .glassCard(cornerRadius: Radius.lg)
    }

    private var emptyState: some View {
        VStack(spacing: Space.md) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 52))
                .foregroundStyle(.white.opacity(0.8))
            Text("No trips yet")
                .rounded(22, weight: .semibold)
                .foregroundStyle(.white)
            Text("Your calculations are saved here automatically.")
                .rounded(15)
                .foregroundStyle(Color.aigosTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Space.xl)
    }

    private func delete(_ trip: TripRecord) {
        context.delete(trip)
        try? context.save()
    }
}

/// Trips grouped by calendar month, newest first.
struct MonthGroup: Identifiable {
    let id: Int                 // year*12 + month
    let title: String
    let trips: [TripRecord]

    static func group(_ trips: [TripRecord]) -> [MonthGroup] {
        let cal = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"

        let grouped = Dictionary(grouping: trips) { trip -> Int in
            let c = cal.dateComponents([.year, .month], from: trip.calculatedAt)
            return (c.year ?? 0) * 12 + (c.month ?? 0)
        }
        return grouped
            .map { key, value in
                MonthGroup(id: key, title: formatter.string(from: value.first!.calculatedAt), trips: value)
            }
            .sorted { $0.id > $1.id }
    }

    /// Total spend for the month `monthsAgo` relative to now (0 = current month).
    static func total(_ trips: [TripRecord], monthsAgo: Int) -> Double {
        let cal = Calendar.current
        guard let target = cal.date(byAdding: .month, value: -monthsAgo, to: Date()) else { return 0 }
        let tc = cal.dateComponents([.year, .month], from: target)
        return trips
            .filter {
                let c = cal.dateComponents([.year, .month], from: $0.calculatedAt)
                return c.year == tc.year && c.month == tc.month
            }
            .reduce(0) { $0 + $1.totalCostPHP }
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: [
            VehicleProfile.self, DrivingProfile.self, TripRecord.self,
            SavedRoute.self, FuelPriceCache.self,
            PersonalPlace.self,
        ], inMemory: true)
}
