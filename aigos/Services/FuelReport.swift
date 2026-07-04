//
//  FuelReport.swift
//  aigos
//
//  Aggregates TripRecords + FuelLogs into the monthly fuel report and computes the
//  vehicle's real fill-to-fill efficiency. Pure/deterministic — testable.
//

import Foundation

struct MonthlyReport {
    let monthLabel: String        // "November 2026"
    let tripCount: Int
    let totalDistanceKm: Double
    let totalFuelL: Double
    let totalSpentPHP: Double
    let avgTripCostPHP: Double
    let avgKmL: Double

    let mostExpensive: (title: String, cost: Double)?
    let cheapest: (title: String, cost: Double)?
    let mostFrequent: (title: String, count: Int)?

    // vs previous month (nil if no prior data)
    let spendDeltaPHP: Double?
    let spendDeltaPct: Double?
    let distanceDeltaKm: Double?
    let tripsDelta: Int?

    var isEmpty: Bool { tripCount == 0 }
}

enum FuelReport {

    /// Build the report for the month containing `date`, from all trips + logs.
    static func monthly(for date: Date, trips: [TripRecord], logs: [FuelLog] = [],
                        calendar: Calendar = .current) -> MonthlyReport {
        let inMonth = trips.filter { calendar.isDate($0.calculatedAt, equalTo: date, toGranularity: .month) }
        let prevDate = calendar.date(byAdding: .month, value: -1, to: date) ?? date
        let inPrev = trips.filter { calendar.isDate($0.calculatedAt, equalTo: prevDate, toGranularity: .month) }

        let label = monthLabel(date, calendar: calendar)
        guard !inMonth.isEmpty else {
            return MonthlyReport(monthLabel: label, tripCount: 0, totalDistanceKm: 0, totalFuelL: 0,
                                 totalSpentPHP: 0, avgTripCostPHP: 0, avgKmL: 0,
                                 mostExpensive: nil, cheapest: nil, mostFrequent: nil,
                                 spendDeltaPHP: nil, spendDeltaPct: nil, distanceDeltaKm: nil, tripsDelta: nil)
        }

        // Prefer real fuel spend from logs when present; else the trips' estimated cost.
        let logSpend = logs.filter { calendar.isDate($0.date, equalTo: date, toGranularity: .month) }
            .reduce(0) { $0 + $1.totalCostPHP }
        let tripSpend = inMonth.reduce(0) { $0 + $1.totalCostPHP }
        let totalSpent = logSpend > 0 ? logSpend : tripSpend

        let distance = inMonth.reduce(0) { $0 + $1.distanceKm }
        let fuel = inMonth.reduce(0) { $0 + $1.adjustedLitres }
        let avgKmL = fuel > 0 ? distance / fuel : 0
        let avgTrip = tripSpend / Double(inMonth.count)

        let expensive = inMonth.max { $0.totalCostPHP < $1.totalCostPHP }
        let cheap = inMonth.min { $0.totalCostPHP < $1.totalCostPHP }
        let freq = frequentTitle(inMonth)

        let prevSpend = inPrev.reduce(0) { $0 + $1.totalCostPHP }
        let prevDistance = inPrev.reduce(0) { $0 + $1.distanceKm }
        let hasPrev = !inPrev.isEmpty

        return MonthlyReport(
            monthLabel: label,
            tripCount: inMonth.count,
            totalDistanceKm: distance,
            totalFuelL: fuel,
            totalSpentPHP: totalSpent,
            avgTripCostPHP: avgTrip,
            avgKmL: avgKmL,
            mostExpensive: expensive.map { (routeTitle($0), $0.totalCostPHP) },
            cheapest: cheap.map { (routeTitle($0), $0.totalCostPHP) },
            mostFrequent: freq,
            spendDeltaPHP: hasPrev ? tripSpend - prevSpend : nil,
            spendDeltaPct: hasPrev && prevSpend > 0 ? (tripSpend - prevSpend) / prevSpend * 100 : nil,
            distanceDeltaKm: hasPrev ? distance - prevDistance : nil,
            tripsDelta: hasPrev ? inMonth.count - inPrev.count : nil)
    }

    /// Real fill-to-fill km/L from the two most recent full-tank logs with odometers.
    static func trueEfficiency(from logs: [FuelLog]) -> (kmL: Double, distanceKm: Double, litres: Double)? {
        let full = logs.filter { $0.isFullTank && $0.odometerKm != nil }
            .sorted { ($0.odometerKm ?? 0) < ($1.odometerKm ?? 0) }
        guard full.count >= 2 else { return nil }
        let a = full[full.count - 2], b = full[full.count - 1]
        guard let o1 = a.odometerKm, let o2 = b.odometerKm,
              let kmL = TripMetrics.actualKmL(odometerStart: o1, odometerEnd: o2, litresAtEnd: b.litersPurchased)
        else { return nil }
        return (kmL, o2 - o1, b.litersPurchased)
    }

    // MARK: - Helpers

    private static func routeTitle(_ t: TripRecord) -> String {
        "\(t.origin) → \(t.destination)"
    }

    private static func frequentTitle(_ trips: [TripRecord]) -> (title: String, count: Int)? {
        let counts = Dictionary(grouping: trips, by: { "\($0.origin) → \($0.destination)" }).mapValues(\.count)
        guard let top = counts.max(by: { $0.value != $1.value ? $0.value < $1.value : $0.key > $1.key }),
              top.value >= 1 else { return nil }
        return (top.key, top.value)
    }

    static func monthLabel(_ date: Date, calendar: Calendar = .current) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }
}
