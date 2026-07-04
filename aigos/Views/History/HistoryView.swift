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
    @Query(sort: \FuelLog.date, order: .reverse) private var fuelLogs: [FuelLog]
    @Query private var vehicles: [VehicleProfile]

    @State private var segment = 0
    @State private var showingLogFuel = false

    private var months: [MonthGroup] { MonthGroup.group(trips) }

    var body: some View {
        ZStack {
            AigosBackground(variant: 1, mascotPeek: CGSize(width: 65, height: -80))

            VStack(spacing: Space.md) {
                Text("HISTORY").screenTitle()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Space.screen)
                    .padding(.top, Space.xl)

                Picker("", selection: $segment) {
                    Text("Trips").tag(0)
                    Text("Fuel Log").tag(1)
                    Text("Report").tag(2)
                }
                .pickerStyle(.segmented)
                .colorScheme(.dark)
                .padding(.horizontal, Space.screen)

                switch segment {
                case 1: fuelLogTab
                case 2: reportTab
                default: tripsTab
                }
            }
        }
        .sheet(isPresented: $showingLogFuel) { FuelLogFormView() }
    }

    // MARK: - Trips tab

    private var tripsTab: some View {
        Group {
            if trips.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Space.lg) {
                        summaryCard
                        ForEach(months) { group in
                            VStack(alignment: .leading, spacing: Space.sm) {
                                Text(group.title.uppercased())
                                    .rounded(13, weight: .semibold)
                                    .kerning(1.2)
                                    .foregroundStyle(Color.aigosTextTertiary)
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
                    .padding(.bottom, Space.xxl)
                }
            }
        }
    }

    // MARK: - Fuel Log tab

    private var fuelLogTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                Button { Haptics.tap(.light); showingLogFuel = true } label: {
                    HStack(spacing: 8) { Image(systemName: "plus.circle.fill"); Text("Log Fuel Purchase") }
                        .rounded(17, weight: .bold).foregroundStyle(Color.aigosAmberDeep)
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                        .background(Color.aigosAmber, in: Capsule())
                }
                .buttonStyle(.plain)

                if let eff = FuelReport.trueEfficiency(from: fuelLogs) { trueEfficiencyCard(eff) }

                if fuelLogs.isEmpty {
                    Text("No fuel logs yet. Log every full-tank fill-up (with the odometer) and aigos will work out your real km/L.")
                        .rounded(14).foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .center).padding(.top, Space.xl)
                } else {
                    let monthTotal = fuelLogs.filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month) }
                        .reduce(0) { $0 + $1.totalCostPHP }
                    Text("This month's fuel spend: \(monthTotal.phpString)")
                        .rounded(14, weight: .semibold).foregroundStyle(.white)
                    ForEach(fuelLogs) { log in fuelLogRow(log) }
                }
            }
            .padding(.horizontal, Space.screen).padding(.bottom, Space.xxl)
        }
    }

    private func fuelLogRow(_ log: FuelLog) -> some View {
        HStack(spacing: Space.md) {
            Image(systemName: "fuelpump.fill").foregroundStyle(Color.aigosAmber).frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(log.stationName ?? log.vehicleName).rounded(16, weight: .semibold).foregroundStyle(.white)
                Text("\(log.date.formatted(date: .abbreviated, time: .omitted)) · \(log.litersPurchased.oneDecimal) L · PHP \(log.pricePerLiter.oneDecimal)/L")
                    .rounded(12).foregroundStyle(Color.aigosTextSecondary)
            }
            Spacer()
            Text(log.totalCostPHP.phpString).rounded(15, weight: .bold).foregroundStyle(.white)
        }
        .padding(Space.md).glassCard()
        .contextMenu {
            Button(role: .destructive) { context.delete(log); try? context.save() } label: { Label("Delete", systemImage: "trash") }
        }
    }

    private func trueEfficiencyCard(_ eff: (kmL: Double, distanceKm: Double, litres: Double)) -> some View {
        let rated = (vehicles.first(where: \.isDefault) ?? vehicles.first)?.efficiencyKmL
        return VStack(alignment: .leading, spacing: Space.sm) {
            Text("REAL EFFICIENCY DETECTED 📊").rounded(13, weight: .bold).foregroundStyle(Color.aigosAmberLight)
            Text("Based on your last 2 full-tank fill-ups: \(Int(eff.distanceKm)) km on \(eff.litres.oneDecimal) L.")
                .rounded(13).foregroundStyle(.white.opacity(0.85)).fixedSize(horizontal: false, vertical: true)
            Text("Your ACTUAL km/L: \(eff.kmL.oneDecimal)")
                .rounded(18, weight: .black).foregroundStyle(.white)
            if let rated {
                let pct = Int(((eff.kmL - rated) / rated * 100).rounded())
                Text("Rated: \(rated.oneDecimal) km/L · \(pct >= 0 ? "+" : "")\(pct)% vs rated")
                    .rounded(13).foregroundStyle(.white.opacity(0.7))
                Button { applyRealEfficiency(eff.kmL) } label: {
                    Text("Update my vehicle profile")
                        .rounded(15, weight: .bold).foregroundStyle(Color.aigosAmberDeep)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color.aigosAmber, in: Capsule())
                }
                .buttonStyle(.plain).padding(.top, Space.xs)
            }
        }
        .padding(Space.md).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.aigosAmberDeep.opacity(0.5), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.aigosAmber.opacity(0.4), lineWidth: 1))
    }

    private func applyRealEfficiency(_ kmL: Double) {
        guard let v = vehicles.first(where: \.isDefault) ?? vehicles.first else { return }
        Haptics.success()
        v.efficiencyKmL = kmL
        v.drivingProfile?.lastUpdated = Date()
        try? context.save()
    }

    // MARK: - Report tab

    private var reportTab: some View {
        ScrollView {
            MonthlyReportView(report: FuelReport.monthly(for: Date(), trips: trips, logs: fuelLogs))
                .padding(.horizontal, Space.screen)
                .padding(.vertical, Space.lg)
        }
    }

    private var summaryCard: some View {
        let this = MonthGroup.total(trips, monthsAgo: 0)
        let last = MonthGroup.total(trips, monthsAgo: 1)
        let delta = this - last
        let hasLast = last > 0

        let monthTrips = trips.filter { Calendar.current.isDate($0.calculatedAt, equalTo: Date(), toGranularity: .month) }
        let count = monthTrips.count
        let km = monthTrips.reduce(0) { $0 + $1.distanceKm }
        let avg = count > 0 ? this / Double(count) : 0

        return VStack(alignment: .leading, spacing: Space.md) {
            // Hero: this month's total spend — the first thing the eye lands on.
            VStack(alignment: .leading, spacing: 4) {
                FieldLabel("This month")
                Text(this.phpString)
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }

            Divider().overlay(Color.white.opacity(0.15))

            // Labeled stats row (replaces the bare bar chart).
            HStack(spacing: Space.sm) {
                statBlock(label: "Trips", value: "\(count)")
                statBlock(label: "Distance", value: "≈ \(Int(km.rounded())) km")
                statBlock(label: "Avg / trip", value: "PHP \(Int(avg.rounded()))")
            }

            // Change vs last month, at the bottom.
            if hasLast {
                HStack(spacing: 6) {
                    Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 12, weight: .bold))
                    Text("\(abs(delta).phpString) vs last month")
                        .rounded(14, weight: .medium)
                }
                .foregroundStyle(delta >= 0 ? Color.aigosAmber : Color(hex: "#8FE39B"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.lg)
        .glassCard(cornerRadius: Radius.lg)
    }

    /// One labeled stat "pill": small caps label on top, bold value below.
    private func statBlock(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .kerning(1.0)
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
            TrackedTrip.self,
            FuelLog.self,
        ], inMemory: true)
}
