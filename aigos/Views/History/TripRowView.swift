//
//  TripRowView.swift
//  aigos
//
//  One glass row in the trip history — route, cost, and a compact summary.
//

import SwiftUI

struct TripRowView: View {
    let trip: TripRecord

    private var efficiency: Double {
        trip.adjustedLitres > 0 ? trip.distanceKm / trip.adjustedLitres : 0
    }

    var body: some View {
        HStack(spacing: Space.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(trip.origin) → \(trip.destination)")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("≈ \(trip.distanceKm.oneDecimal) km · \(trip.vehicleName) · \(trip.adjustedLitres.oneDecimal) L")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.65))
                    .lineLimit(1)
                efficiencyBadge
            }
            Spacer()
            Text(trip.totalCostPHP.phpString)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .padding(Space.md)
        .glassCard()
    }

    private var efficiencyBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "leaf.fill").font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
            Text("\(efficiency.oneDecimal) km/L")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(Capsule().fill(Color.white.opacity(0.14)))
    }
}
