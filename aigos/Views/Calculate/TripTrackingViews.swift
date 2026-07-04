//
//  TripTrackingViews.swift
//  aigos
//
//  The live tracking banner/dashboard shown on the Calculate screen while a trip
//  is being GPS-recorded, and the estimate-vs-actual comparison shown when it ends.
//

import SwiftUI

/// Format seconds as mm:ss (or h:mm:ss past an hour).
func formatElapsed(_ s: Int) -> String {
    let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%02d:%02d", m, sec)
}

// MARK: - Live banner + dashboard

struct TripTrackingBanner: View {
    var tracker: TripTracker
    @AppStorage("fuelUnit") private var fuelUnit: FuelUnit = .kmPerL
    let onEnd: () -> Void
    @State private var blink = false

    var body: some View {
        VStack(spacing: Space.md) {
            HStack(spacing: Space.sm) {
                Circle().fill(.red).frame(width: 11, height: 11).opacity(blink ? 0.3 : 1)
                Text("TRACKING: \(tracker.origin) → \(tracker.destination)")
                    .rounded(14, weight: .bold).foregroundStyle(.white).lineLimit(1)
                Spacer(minLength: Space.sm)
                Text(formatElapsed(tracker.elapsedSeconds))
                    .font(.system(size: 15, weight: .bold, design: .monospaced)).foregroundStyle(.white)
            }

            HStack(spacing: Space.md) {
                metric("Distance", "\(tracker.distanceKm.oneDecimal) km", "map.fill")
                metric("Fuel", "\(tracker.fuelL.oneDecimal) L", "fuelpump.fill")
                metric("Cost", tracker.costPHP.phpString, "pesosign.circle.fill")
            }
            HStack(spacing: Space.md) {
                metric("Speed", "\(Int(tracker.currentSpeedKmh)) km/h", "speedometer")
                metric("Elapsed", formatElapsed(tracker.elapsedSeconds), "clock.fill")
            }

            if tracker.status == .arrived {
                Text("Looks like you've arrived 🎉")
                    .rounded(13, weight: .semibold).foregroundStyle(Color.aigosAmberLight)
            } else if tracker.status == .paused {
                Text("⏸ Paused — reopen aigos to keep tracking")
                    .rounded(13, weight: .semibold).foregroundStyle(Color.aigosAmberLight)
            }

            Text("📱 Keep aigos open while driving to track your trip.")
                .rounded(11, weight: .medium).foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)

            Button(action: onEnd) {
                HStack(spacing: 6) { Image(systemName: "stop.fill"); Text("End Trip") }
                    .rounded(16, weight: .bold).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Color(hex: "#C0392B"), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(Space.md)
        .background(Color.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.red.opacity(0.5), lineWidth: 1.5))
        .onAppear { withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { blink = true } }
    }

    private func metric(_ label: String, _ value: String, _ icon: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 13)).foregroundStyle(Color.aigosAmber)
            Text(value).rounded(16, weight: .bold).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).rounded(10, weight: .semibold).foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Estimate vs actual comparison

struct TripComparisonView: View {
    let summary: TripSummary
    let estDistanceKm: Double
    let estFuelL: Double
    let estCostPHP: Double
    let vehicleName: String
    let ratedKmL: Double
    let onUpdateProfile: (Double) -> Void   // passes the suggested new efficiency (km/L)
    let onKeep: () -> Void

    @Environment(\.dismiss) private var dismiss

    /// Effective km/L implied by how far off the distance estimate was. aigos has no
    /// fuel sensor, so we fold the distance-estimate error into an effective
    /// efficiency: rated × (estimated ÷ actual). Clamped so one odd trip can't swing
    /// it wildly. This makes future estimates on this route land closer to reality.
    private var impliedKmL: Double {
        guard summary.actualDistanceKm > 0, estDistanceKm > 0 else { return ratedKmL }
        let raw = ratedKmL * (estDistanceKm / summary.actualDistanceKm)
        return min(max(raw, ratedKmL * 0.5), ratedKmL * 1.2)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.lg) {
                    Text("TRIP COMPLETE ✅")
                        .rounded(22, weight: .black).foregroundStyle(.white)

                    VStack(spacing: 0) {
                        headerRow
                        DashedDivider().padding(.vertical, Space.sm)
                        compareRow("Distance", est: "\(estDistanceKm.oneDecimal) km", act: "\(summary.actualDistanceKm.oneDecimal) km")
                        compareRow("Fuel", est: "\(estFuelL.oneDecimal) L", act: "\(summary.actualFuelL.oneDecimal) L")
                        compareRow("Cost", est: estCostPHP.phpString, act: summary.actualCostPHP.phpString)
                    }
                    .padding(Space.lg).glassCard(cornerRadius: Radius.lg)

                    Text("📊 Your estimate was \(Int(summary.accuracyPercent.rounded()))% accurate.")
                        .rounded(16, weight: .bold).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("💡 Your \(vehicleName) worked out to about \(fmt(impliedKmL)) km/L on this route (rated: \(fmt(ratedKmL)) km/L).")
                        .rounded(14).foregroundStyle(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: Space.sm) {
                        Button {
                            Haptics.success()
                            onUpdateProfile(impliedKmL)
                            dismiss()
                        } label: {
                            Text("Update my profile →")
                                .rounded(17, weight: .bold).foregroundStyle(Color.aigosAmberDeep)
                                .frame(maxWidth: .infinity).padding(.vertical, 16)
                                .background(Color.aigosAmber, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        Button {
                            onKeep(); dismiss()
                        } label: {
                            Text("Keep current")
                                .rounded(16, weight: .semibold).foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(Color.white.opacity(0.14), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Space.screen).padding(.vertical, Space.lg)
            }
            .background(AigosBackground())
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var headerRow: some View {
        HStack {
            Text("").frame(maxWidth: .infinity, alignment: .leading)
            Text("ESTIMATED").rounded(11, weight: .bold).foregroundStyle(.white.opacity(0.6)).frame(maxWidth: .infinity, alignment: .trailing)
            Text("ACTUAL").rounded(11, weight: .bold).foregroundStyle(Color.aigosAmber).frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func compareRow(_ label: String, est: String, act: String) -> some View {
        HStack {
            Text(label).rounded(15, weight: .semibold).foregroundStyle(.white.opacity(0.9)).frame(maxWidth: .infinity, alignment: .leading)
            Text(est).rounded(15, weight: .medium).foregroundStyle(.white.opacity(0.7)).frame(maxWidth: .infinity, alignment: .trailing)
            Text(act).rounded(15, weight: .bold).foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, 8)
    }

    private func fmt(_ v: Double) -> String { String(format: "%.1f", v) }
}
