//
//  ResultCard.swift
//  aigos
//
//  The result breakdown (Section 14D). Shows a full, honest breakdown — distance,
//  base litres, each adjustment factor with % and litre amount, adjusted litres,
//  price, and the bold amber total — plus the always-on disclaimer.
//

import SwiftUI

struct ResultCard: View {
    let estimate: FuelEstimate
    let fuelType: FuelType

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            breakdownRows

            Divider()

            HStack(alignment: .firstTextBaseline) {
                Text("ESTIMATED COST")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(estimate.estimatedCost.phpString)
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.aigosAmber)
            }

            Label(
                "Estimate only. Tap any value to adjust.",
                systemImage: "exclamationmark.triangle"
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    private var breakdownRows: some View {
        VStack(spacing: 8) {
            row("Distance", value: "\(estimate.distanceKm.oneDecimal) km")
            row(
                "Base fuel (rated)",
                value: "\(estimate.baseLitres.oneDecimal) L",
                detail: "at \(estimate.baseEfficiencyKmL.oneDecimal) km/L"
            )
            adjustmentRow(
                "Speed adjustment",
                factor: estimate.speedFactor
            )
            adjustmentRow(
                "AC adjustment",
                factor: estimate.acFactor
            )
            adjustmentRow(
                "Road adjustment",
                factor: estimate.roadFactor
            )
            row(
                "Adjusted fuel",
                value: "\(estimate.adjustedLitres.oneDecimal) L",
                emphasised: true
            )
            row(
                "Fuel price",
                value: "\(estimate.fuelPricePerLitre.phpString) / L",
                detail: fuelType.label
            )
        }
    }

    private func adjustmentRow(_ title: String, factor: Double) -> some View {
        let litres = estimate.litres(forFactor: factor)
        let litreText = abs(litres) < 0.05
            ? "0.0 L"
            : "\(litres > 0 ? "+" : "")\(litres.oneDecimal) L"
        return row(title, value: factor.factorPercentString, detail: litreText)
    }

    private func row(
        _ title: String,
        value: String,
        detail: String? = nil,
        emphasised: Bool = false
    ) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.primary)
            Spacer()
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Text(value)
                .fontWeight(emphasised ? .semibold : .regular)
                .monospacedDigit()
        }
        .font(.subheadline)
    }
}

#Preview {
    ResultCard(
        estimate: CalculationEngine.estimate(
            distanceKm: 82.4,
            baseEfficiencyKmL: 14.5,
            fuelPricePerLitre: 62.55,
            avgHighwaySpeedKmh: 110,
            avgCitySpeedKmh: 40,
            acInUse: true,
            roadType: .highway
        ),
        fuelType: .ron95
    )
    .padding()
}
