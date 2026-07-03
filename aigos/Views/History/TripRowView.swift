//
//  TripRowView.swift
//  aigos
//
//  One glass row in the trip history — route, cost, and a compact summary.
//

import SwiftUI

struct TripRowView: View {
    let trip: TripRecord

    var body: some View {
        HStack(spacing: Space.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(trip.origin) → \(trip.destination)")
                    .rounded(16, weight: .semibold)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("\(trip.distanceKm.oneDecimal) km · \(trip.vehicleName) · \(trip.adjustedLitres.oneDecimal) L")
                    .rounded(13)
                    .foregroundStyle(Color.aigosTextSecondary)
                    .lineLimit(1)
                Text(trip.calculatedAt.formatted(date: .abbreviated, time: .shortened))
                    .rounded(11)
                    .foregroundStyle(Color.aigosTextTertiary)
            }
            Spacer()
            Text(trip.totalCostPHP.phpString)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Color.aigosAmber)
        }
        .padding(Space.md)
        .glassCard()
    }
}
