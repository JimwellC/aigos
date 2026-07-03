//
//  ResultCard.swift
//  aigos
//
//  The result as a premium "receipt": a big centered cost, a dashed divider, an
//  itemised breakdown with icons + amber percentage badges, a fuel-gauge bar, and
//  the disclaimer in its own box.
//

import SwiftUI

struct ResultCard: View {
    @AppStorage("fuelUnit") private var fuelUnit: FuelUnit = .kmPerL
    let estimate: FuelEstimate
    let heroCost: Double
    let confidence: String?
    var tankLiters: Double? = nil

    @State private var warningShake: CGFloat = 0

    var body: some View {
        VStack(spacing: Space.lg) {
            heroCostView

            DashedDivider()

            VStack(spacing: 12) {
                infoRow("map.fill", "Distance", "\(estimate.distanceKm.oneDecimal) km")
                infoRow("drop.fill", "Base fuel",
                        "\(estimate.baseLitres.oneDecimal) L",
                        detail: "at \(fuelUnit.format(kmL: estimate.baseEfficiencyKmL))")
                adjustmentRow("speedometer", "Speed", estimate.speedFactor)
                adjustmentRow("snowflake", "Aircon", estimate.acFactor)
                adjustmentRow("road.lanes", "Road type", estimate.roadFactor)
                adjustmentRow("car.2.fill", "Traffic", estimate.trafficFactor)
                adjustmentRow("person.2.fill", "Load", estimate.loadFactor)
            }

            DashedDivider()

            infoRow("fuelpump.fill", "Fuel needed", "\(estimate.adjustedLitres.oneDecimal) L", emphasised: true)

            if let tankLiters {
                fuelGauge(tank: tankLiters)
            }

            if estimate.needsRefuel {
                refuelWarning
                    .modifier(Shake(animatableData: warningShake))
                    .onAppear {
                        warningShake = 0
                        withAnimation(.easeInOut(duration: 0.5)) { warningShake = 1 }
                    }
            }

            if let confidence {
                Label(confidence, systemImage: "brain.head.profile")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.7))
            }

            Text("Estimate only. Actual fuel use varies with traffic, load, and driving style. Tap any input to adjust.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(Space.sm)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(Space.lg)
        .glassCard(cornerRadius: Radius.lg)
    }

    // MARK: - Hero

    private var heroCostView: some View {
        VStack(spacing: 4) {
            Text("ESTIMATED COST")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .kerning(2.0)
                .foregroundStyle(Color.white.opacity(0.7))
            Text(heroCost.phpString)
                .font(.system(size: 52, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText(value: heroCost))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
    }

    // MARK: - Rows

    private func infoRow(_ icon: String, _ name: String, _ value: String, detail: String? = nil, emphasised: Bool = false) -> some View {
        HStack(spacing: Space.sm) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(emphasised ? Color.aigosAmber : Color.white.opacity(0.75))
                .frame(width: 22)
            Text(name)
                .font(.system(size: 16, weight: emphasised ? .bold : .medium, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            if let detail {
                Text(detail)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
            Text(value)
                .font(.system(size: emphasised ? 20 : 17, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
    }

    private func adjustmentRow(_ icon: String, _ name: String, _ factor: Double) -> some View {
        let litres = estimate.litres(forFactor: factor)
        let litreText = abs(litres) < 0.05 ? "" : "\(litres > 0 ? "+" : "")\(litres.oneDecimal) L"
        return HStack(spacing: Space.sm) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.75))
                .frame(width: 22)
            Text(name)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            if !litreText.isEmpty {
                Text(litreText)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
            Text(factor.factorPercentString)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(factor > 1.0 ? .white : Color.white.opacity(0.7))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(factor > 1.0 ? Color.aigosAmber.opacity(0.9) : Color.white.opacity(0.15))
                )
        }
    }

    // MARK: - Fuel gauge

    private func fuelGauge(tank: Double) -> some View {
        let fraction = min(estimate.adjustedLitres / max(tank, 1), 1.0)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("FUEL GAUGE")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .kerning(1.5)
                    .foregroundStyle(Color.white.opacity(0.55))
                Spacer()
                Text("\(estimate.adjustedLitres.oneDecimal) L of ~\(Int(tank)) L tank")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.7))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.15))
                    Capsule()
                        .fill(LinearGradient(colors: [Color.aigosAmberLight, Color.aigosAmberDeep],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(8, geo.size.width * fraction))
                }
            }
            .frame(height: 12)
        }
    }

    private var refuelWarning: some View {
        HStack(spacing: Space.sm) {
            Image(systemName: "fuelpump.exclamationmark")
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 1) {
                Text("You may need to refuel")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                if let available = estimate.availableFuelLitres {
                    Text("Needs ~\(estimate.adjustedLitres.oneDecimal) L · tank ~\(available.oneDecimal) L")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            Spacer()
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.aigosAmberDeep.opacity(0.9), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// A horizontal dashed hairline.
struct DashedDivider: View {
    var body: some View {
        GeometryReader { g in
            Path { p in
                p.move(to: CGPoint(x: 0, y: 0.5))
                p.addLine(to: CGPoint(x: g.size.width, y: 0.5))
            }
            .stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
        }
        .frame(height: 1)
    }
}

#Preview {
    ZStack {
        AigosBackground()
        ScrollView {
            ResultCard(
                estimate: CalculationEngine.estimate(
                    distanceKm: 82.4, baseEfficiencyKmL: 14.5, fuelPricePerLitre: 62.55,
                    avgHighwaySpeedKmh: 110, avgCitySpeedKmh: 40, acInUse: true, roadType: .city,
                    traffic: .heavy, load: .moderate, availableFuelLitres: 6
                ),
                heroCost: 713.80,
                confidence: "Getting to know you · 8 trips",
                tankLiters: 45
            )
            .padding()
        }
    }
}
