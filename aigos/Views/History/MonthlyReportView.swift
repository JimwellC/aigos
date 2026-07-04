//
//  MonthlyReportView.swift
//  aigos
//
//  The monthly fuel report (v1.1): on-screen summary + a shareable image rendered
//  with SwiftUI ImageRenderer (Instagram-Story sized). All computed on-device.
//

import SwiftUI

struct MonthlyReportView: View {
    let report: MonthlyReport
    @State private var shareImage: ShareableImage?

    var body: some View {
        Group {
            if report.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: Space.lg) {
                    reportCard
                    Button {
                        renderAndShare()
                    } label: {
                        HStack(spacing: 8) { Image(systemName: "square.and.arrow.up"); Text("Share report") }
                            .rounded(17, weight: .bold).foregroundStyle(Color.aigosAmberDeep)
                            .frame(maxWidth: .infinity).padding(.vertical, 15)
                            .background(Color.aigosAmber, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(item: $shareImage) { img in
            ActivityView(items: [img.image, shareCaption])
        }
    }

    private var shareCaption: String {
        "My \(report.monthLabel) fuel report from aigos! ⛽ \(report.totalSpentPHP.phpString) on \(report.tripCount) trips. Know before you go 🇵🇭"
    }

    // MARK: - On-screen card

    private var reportCard: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("YOUR \(report.monthLabel.uppercased()) REPORT")
                .rounded(15, weight: .black).foregroundStyle(.white)

            statGrid
            DashedDivider()

            if let e = report.mostExpensive { line("Most expensive", "\(e.title) — \(e.cost.phpString)") }
            if let c = report.cheapest { line("Cheapest", "\(c.title) — \(c.cost.phpString)") }
            if let f = report.mostFrequent { line("Most frequent", "\(f.title) (\(f.count)×)") }

            if report.spendDeltaPHP != nil { DashedDivider(); vsLastMonth }
        }
        .padding(Space.lg).frame(maxWidth: .infinity, alignment: .leading).glassCard(cornerRadius: Radius.lg)
    }

    private var statGrid: some View {
        VStack(spacing: Space.sm) {
            HStack {
                stat("🚗", "Trips", "\(report.tripCount)")
                stat("📏", "Distance", "\(Int(report.totalDistanceKm)) km")
                stat("⛽", "Fuel", "\(report.totalFuelL.oneDecimal) L")
            }
            HStack {
                stat("💰", "Spent", report.totalSpentPHP.phpString)
                stat("📊", "Avg/trip", report.avgTripCostPHP.phpString)
                stat("⚡", "km/L", report.avgKmL.oneDecimal)
            }
        }
    }

    private var vsLastMonth: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("VS LAST MONTH").rounded(11, weight: .bold).foregroundStyle(.white.opacity(0.55))
            if let d = report.spendDeltaPHP, let p = report.spendDeltaPct {
                delta("Fuel spend", d, unit: "PHP", pct: p, goodWhenDown: true)
            }
            if let d = report.distanceDeltaKm { delta("Distance", d, unit: "km", pct: nil, goodWhenDown: false) }
            if let t = report.tripsDelta { delta("Trips", Double(t), unit: "", pct: nil, goodWhenDown: false) }
        }
    }

    private func delta(_ label: String, _ value: Double, unit: String, pct: Double?, goodWhenDown: Bool) -> some View {
        let up = value > 0
        let arrow = up ? "↑" : "↓"
        let magnitude = unit == "PHP" ? abs(value).phpString : "\(Int(abs(value)))\(unit.isEmpty ? "" : " " + unit)"
        let pctText = pct.map { " (\(up ? "+" : "")\(Int($0.rounded()))%)" } ?? ""
        return HStack {
            Text(label).rounded(13).foregroundStyle(.white.opacity(0.85))
            Spacer()
            Text("\(arrow) \(magnitude)\(pctText)")
                .rounded(13, weight: .semibold)
                .foregroundStyle((up != goodWhenDown) ? Color(hex: "#7ED957") : Color.aigosAmberLight)
        }
    }

    private func stat(_ emoji: String, _ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).rounded(17, weight: .bold).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.6)
            Text("\(emoji) \(label)").rounded(11).foregroundStyle(.white.opacity(0.6)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private func line(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).rounded(13, weight: .semibold).foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text(value).rounded(13, weight: .medium).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
        }
    }

    private var emptyState: some View {
        VStack(spacing: Space.md) {
            MascotView(size: 120, floating: true)
            Text("No trips this month yet!")
                .rounded(18, weight: .bold).foregroundStyle(.white)
            Text("Calculate your first trip to start building your fuel report.")
                .rounded(14).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.top, Space.xxl)
    }

    // MARK: - Share image

    @MainActor private func renderAndShare() {
        let renderer = ImageRenderer(content: ReportShareCard(report: report))
        renderer.scale = 3
        if let ui = renderer.uiImage {
            shareImage = ShareableImage(image: ui)
        }
    }
}

struct ShareableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// The 1080×1920 Instagram-Story share card (rendered off-screen).
struct ReportShareCard: View {
    let report: MonthlyReport

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 60)
            Text("MY \(report.monthLabel.uppercased())\nFUEL REPORT")
                .font(.system(size: 66, weight: .black, design: .rounded))
                .multilineTextAlignment(.center).foregroundStyle(.white)

            VStack(spacing: 18) {
                bigStat("💰 Total spent", report.totalSpentPHP.phpString)
                bigStat("🚗 Trips", "\(report.tripCount)")
                bigStat("📏 Distance", "\(Int(report.totalDistanceKm)) km")
                bigStat("⚡ Avg efficiency", "\(report.avgKmL.oneDecimal) km/L")
            }
            .padding(40)
            .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            .padding(.horizontal, 60)

            Spacer()
            MascotView(size: 200)
            Text("Made with aigos 🇵🇭")
                .font(.system(size: 40, weight: .bold, design: .rounded)).foregroundStyle(.white)
            Spacer(minLength: 60)
        }
        .frame(width: 1080, height: 1920)
        .background(
            LinearGradient(colors: [Color(hex: "#F5C97A"), Color(hex: "#C4793A")],
                           startPoint: .topLeading, endPoint: .bottomTrailing))
    }

    private func bigStat(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 42, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.9))
            Spacer()
            Text(value).font(.system(size: 46, weight: .black, design: .rounded)).foregroundStyle(.white)
        }
    }
}

/// UIActivityViewController bridge for sharing the report image.
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
