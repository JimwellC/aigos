//
//  ResultCard.swift
//  aigos
//
//  The result breakdown (Section 14D) as a glassmorphism hero card. The estimated
//  cost is the hero — 52pt bold rounded white, counting up on appear. Below it, a
//  full, honest breakdown, a confidence line, and the always-on disclaimer.
//

import SwiftUI

struct ResultCard: View {
    let estimate: FuelEstimate
    /// Animated cost value driven by the parent's count-up.
    let heroCost: Double
    let confidence: String?

    var body: some View {
        VStack(spacing: Space.lg) {
            heroCostView

            VStack(spacing: 10) {
                row("Distance", value: "\(estimate.distanceKm.oneDecimal) km")
                row("Base fuel (rated)",
                    value: "\(estimate.baseLitres.oneDecimal) L",
                    detail: "at \(estimate.baseEfficiencyKmL.oneDecimal) km/L")
                adjustmentRow("Speed", factor: estimate.speedFactor)
                adjustmentRow("Aircon", factor: estimate.acFactor)
                adjustmentRow("Road", factor: estimate.roadFactor)
                Divider().overlay(Color.white.opacity(0.2))
                row("Adjusted fuel", value: "\(estimate.adjustedLitres.oneDecimal) L", emphasised: true)
                row("Fuel price", value: "\(estimate.fuelPricePerLitre.phpString) / L")
            }

            if let confidence {
                Label(confidence, systemImage: "brain.head.profile")
                    .rounded(13, weight: .medium)
                    .foregroundStyle(Color.aigosTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            Text("Estimate only. Tap any value to adjust.")
                .rounded(12)
                .foregroundStyle(Color.aigosTextTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(Space.lg)
        .glassCard(cornerRadius: Radius.lg)
    }

    private var heroCostView: some View {
        VStack(spacing: 2) {
            Text("ESTIMATED COST")
                .rounded(12, weight: .medium)
                .kerning(1.5)
                .foregroundStyle(Color.aigosTextSecondary)
            Text(heroCost.phpString)
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText(value: heroCost))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
    }

    private func adjustmentRow(_ title: String, factor: Double) -> some View {
        let litres = estimate.litres(forFactor: factor)
        let litreText = abs(litres) < 0.05
            ? "0.0 L"
            : "\(litres > 0 ? "+" : "")\(litres.oneDecimal) L"
        return row("\(title) adjustment", value: factor.factorPercentString, detail: litreText)
    }

    private func row(_ title: String, value: String, detail: String? = nil, emphasised: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .rounded(15, weight: emphasised ? .semibold : .regular)
                .foregroundStyle(.white)
            Spacer()
            if let detail {
                Text(detail)
                    .rounded(12)
                    .foregroundStyle(Color.aigosTextTertiary)
            }
            Text(value)
                .font(.system(size: 15, weight: emphasised ? .bold : .medium, design: .monospaced))
                .foregroundStyle(emphasised ? Color.aigosAmber : .white)
        }
    }
}

#Preview {
    ZStack {
        AigosBackground()
        ResultCard(
            estimate: CalculationEngine.estimate(
                distanceKm: 82.4, baseEfficiencyKmL: 14.5, fuelPricePerLitre: 62.55,
                avgHighwaySpeedKmh: 110, avgCitySpeedKmh: 40, acInUse: true, roadType: .highway
            ),
            heroCost: 449.87,
            confidence: "Getting to know you · 8 trips"
        )
        .padding()
    }
}
