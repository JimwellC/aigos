//
//  TripRowView.swift
//  aigos
//
//  One row in the trip history — route, cost, and a compact factor summary.
//

import SwiftUI

struct TripRowView: View {
    let trip: TripRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(trip.origin) → \(trip.destination)")
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(trip.totalCostPHP.phpString)
                    .font(.headline)
                    .foregroundStyle(Color.aigosAmber)
            }
            HStack(spacing: 8) {
                Text("\(trip.distanceKm.oneDecimal) km")
                Text("·")
                Text(trip.vehicleName)
                Text("·")
                Text("\(trip.adjustedLitres.oneDecimal) L")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(trip.calculatedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}
