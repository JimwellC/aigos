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
            AigosBackground(variant: 1)

            if trips.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Space.lg) {
                        Text("HISTORY").screenTitle()

                        summaryCard
                        if trips.count >= 2 { spendChart }

                        ForEach(months) { group in
                            VStack(alignment: .leading, spacing: Space.sm) {
                                Text(group.title.uppercased())
                                    .rounded(13, weight: .semibold)
                                    .kerning(1.2)
                                    .foregroundStyle(Color.aigosTextTertiary)
                                    // Fades in as the section scrolls into view (LazyVStack).
                                    .staggeredAppear(yOffset: 8)

                                ForEach(Array(group.trips.enumerated()), id: \.element.id) { i, trip in
                                    TripRowView(trip: trip)
                                        .staggeredAppear(index: i)
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

        let count = trips.filter { Calendar.current.isDate($0.calculatedAt, equalTo: Date(), toGranularity: .month) }.count

        return VStack(alignment: .leading, spacing: Space.sm) {
            FieldLabel("This month")
            Text(this.phpString)
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            HStack(spacing: Space.sm) {
                statPill(icon: "car.fill", text: "\(count) trip\(count == 1 ? "" : "s")", tint: .white.opacity(0.85))
                if hasLast {
                    statPill(icon: delta >= 0 ? "arrow.up.right" : "arrow.down.right",
                             text: "\(abs(delta).phpString) vs last month",
                             tint: delta >= 0 ? Color.aigosAmber : Color(hex: "#8FE39B"))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.lg)
        .glassCard(cornerRadius: Radius.lg)
    }

    private func statPill(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11, weight: .bold))
            Text(text).font(.system(size: 13, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Capsule().fill(Color.white.opacity(0.14)))
    }

    /// Amber bar chart of the most recent trips' spend.
    private var spendChart: some View {
        let recent = Array(trips.prefix(8).reversed())
        let maxCost = recent.map(\.totalCostPHP).max() ?? 1
        return VStack(alignment: .leading, spacing: Space.sm) {
            FieldLabel("Recent spend")
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(recent) { trip in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(LinearGradient(colors: [Color.aigosAmberLight, Color.aigosAmberDeep],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(height: max(10, CGFloat(trip.totalCostPHP / maxCost) * 92))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 100)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.md)
        .glassCard()
    }

    private var emptyState: some View {
        MascotEmptyState(
            title: "No trips yet",
            message: "Your trips will appear here. Calculate your first trip!"
        )
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
