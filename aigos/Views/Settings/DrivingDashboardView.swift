//
//  DrivingDashboardView.swift
//  aigos
//
//  Smart Driving Insights dashboard (Feature 4): the vehicle's fuel-efficiency
//  score, learned driving stats, personalized tips, a side-by-side vehicle
//  comparison, and a shareable score card. All computed on-device.
//

import SwiftUI
import SwiftData

struct DrivingDashboardView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \VehicleProfile.createdAt) private var vehicles: [VehicleProfile]
    @Query(sort: \TripRecord.calculatedAt, order: .reverse) private var trips: [TripRecord]
    @Query private var trackedTrips: [TrackedTrip]
    @AppStorage("fuelUnit") private var fuelUnit: FuelUnit = .kmPerL

    @State private var selectedID: UUID?
    @State private var shareImage: ShareableImage?

    private var vehicle: VehicleProfile? {
        vehicles.first { $0.id == selectedID } ?? vehicles.first(where: \.isDefault) ?? vehicles.first
    }
    private func vehicleTrips(_ v: VehicleProfile) -> [TripRecord] {
        trips.filter { $0.vehicleName == v.name }
    }
    private func recentTrips(_ v: VehicleProfile) -> [TripRecord] {
        let cutoff = Date().addingTimeInterval(-30 * 24 * 3600)
        return vehicleTrips(v).filter { $0.calculatedAt >= cutoff }
    }
    private func monthlyCost(_ v: VehicleProfile) -> Double {
        recentTrips(v).reduce(0) { $0 + $1.totalCostPHP }
    }
    private func score(_ v: VehicleProfile) -> DrivingScore {
        DrivingScorer.score(for: v, trips: vehicleTrips(v), trackedTrips: trackedTrips)
    }

    private var suggestions: [Suggestion] {
        guard let v = vehicle else { return [] }
        let cands = SuggestionEngine.candidates(
            vehicle: v, trips: vehicleTrips(v), now: Date(),
            currentFuelPrice: PriceService.price(for: v.fuelType, in: context),
            unleaded91Price: PriceService.price(for: .unleaded91, in: context))
        return SuggestionEngine.pick(cands, recentlyShownAt: SuggestionLog.shownAt, now: Date())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AigosBackground()
                if let v = vehicle {
                    ScrollView {
                        VStack(spacing: Space.lg) {
                            if vehicles.count > 1 { vehiclePicker }
                            scoreCard(v)
                            statsCard(v)
                            if !suggestions.isEmpty { tipsSection }
                            if vehicles.count > 1 { comparisonCard }
                            shareButton(v)
                        }
                        .padding(.horizontal, Space.screen).padding(.vertical, Space.lg)
                    }
                } else {
                    MascotEmptyState(title: "No insights yet", message: "Add a vehicle and take a few trips — your driving insights will appear here.")
                }
            }
            .navigationTitle("Driving Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.aigosAmberDeep, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.tint(.white) } }
            .sheet(item: $shareImage) { img in ActivityView(items: [img.image, shareCaption]) }
        }
    }

    private var shareCaption: String {
        guard let v = vehicle else { return "My aigos driving score" }
        return "My \(v.name) scored \(score(v).total)/100 on aigos — \(score(v).label). Know before you go 🇵🇭⛽"
    }

    // MARK: - Vehicle picker

    private var vehiclePicker: some View {
        Menu {
            ForEach(vehicles) { v in
                Button(v.name) { selectedID = v.id }
            }
        } label: {
            HStack {
                Text(vehicle?.name ?? "Vehicle").rounded(16, weight: .bold).foregroundStyle(.white)
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 12)).foregroundStyle(Color.aigosAmber)
            }
            .padding(.horizontal, Space.md).padding(.vertical, 10).glassCard()
        }
    }

    // MARK: - Score card

    private func scoreCard(_ v: VehicleProfile) -> some View {
        let s = score(v)
        return VStack(spacing: Space.md) {
            ScoreRing(score: s.total)
            Text(s.label).rounded(20, weight: .black).foregroundStyle(.white)
            VStack(spacing: 6) {
                scoreBar("Speed vs optimal", s.speed, 30)
                scoreBar("AC efficiency", s.ac, 15)
                scoreBar("Smooth driving", s.smoothness, 15)
                scoreBar("Rush-hour avoidance", s.rushHour, 20)
                scoreBar("Maintenance", s.maintenance, 20)
            }
        }
        .padding(Space.lg).frame(maxWidth: .infinity).glassCard(cornerRadius: Radius.lg)
    }

    private func scoreBar(_ label: String, _ value: Int, _ max: Int) -> some View {
        HStack(spacing: Space.sm) {
            Text(label).rounded(12, weight: .medium).foregroundStyle(.white.opacity(0.8))
                .frame(width: 130, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.12))
                    Capsule().fill(Color.aigosAmber)
                        .frame(width: geo.size.width * CGFloat(value) / CGFloat(max))
                }
            }
            .frame(height: 7)
            Text("\(value)/\(max)").rounded(11, weight: .bold).foregroundStyle(.white.opacity(0.7))
                .frame(width: 42, alignment: .trailing)
        }
    }

    // MARK: - Stats card

    private func statsCard(_ v: VehicleProfile) -> some View {
        let p = v.drivingProfile
        let hwy = p?.avgActualHighwaySpeed ?? p?.avgHighwaySpeedKmh ?? 90
        let city = p?.avgActualCitySpeed ?? p?.avgCitySpeedKmh ?? 40
        return VStack(alignment: .leading, spacing: Space.sm) {
            Text("HOW YOU DRIVE").rounded(12, weight: .bold).foregroundStyle(Color.aigosAmberLight)
            statRow("Efficiency", fuelUnit.format(kmL: v.efficiencyKmL))
            statRow("Avg highway speed", "\(Int(hwy)) km/h")
            statRow("Avg city speed", "\(Int(city)) km/h")
            statRow("AC usage", "\(Int((p?.acUsageRate ?? 1) * 100))% of trips")
            statRow("Usual roads", (p?.defaultRoadType ?? .highway).label)
            statRow("Trips learned", "\(p?.tripCount ?? 0)")
            statRow("Profile", (p?.confidenceLevel ?? .new).label)
            statRow("Fuel spend (30 days)", monthlyCost(v).phpString)
        }
        .padding(Space.lg).frame(maxWidth: .infinity, alignment: .leading).glassCard(cornerRadius: Radius.lg)
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).rounded(14).foregroundStyle(.white.opacity(0.75))
            Spacer()
            Text(value).rounded(14, weight: .semibold).foregroundStyle(.white)
        }
    }

    // MARK: - Tips

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("WAYS TO SAVE").rounded(12, weight: .bold).foregroundStyle(Color.aigosAmberLight)
            ForEach(suggestions) { s in SuggestionCard(suggestion: s, onDismiss: nil) }
        }
    }

    // MARK: - Comparison

    private var comparisonCard: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("YOUR GARAGE").rounded(12, weight: .bold).foregroundStyle(Color.aigosAmberLight)
            ForEach(vehicles) { v in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(v.name).rounded(15, weight: .semibold).foregroundStyle(.white)
                        Text("\(fuelUnit.format(kmL: v.efficiencyKmL)) · \(score(v).total)/100")
                            .rounded(12).foregroundStyle(Color.aigosTextSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(monthlyCost(v).phpString).rounded(15, weight: .bold).foregroundStyle(.white)
                        Text("30-day fuel").rounded(10).foregroundStyle(.white.opacity(0.5))
                    }
                }
                .padding(Space.md).glassCard()
            }
        }
    }

    // MARK: - Share

    private func shareButton(_ v: VehicleProfile) -> some View {
        Button { renderShare(v) } label: {
            HStack(spacing: 8) { Image(systemName: "square.and.arrow.up"); Text("Share my score") }
                .rounded(17, weight: .bold).foregroundStyle(Color.aigosAmberDeep)
                .frame(maxWidth: .infinity).padding(.vertical, 15)
                .background(Color.aigosAmber, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    @MainActor private func renderShare(_ v: VehicleProfile) {
        let renderer = ImageRenderer(content: ScoreShareCard(vehicleName: v.name, score: score(v),
                                                             efficiency: fuelUnit.format(kmL: v.efficiencyKmL)))
        renderer.scale = 3
        if let ui = renderer.uiImage { shareImage = ShareableImage(image: ui) }
    }
}

// MARK: - Score ring

struct ScoreRing: View {
    let score: Int
    private var color: Color {
        switch score { case 75...: .init(hex: "#7ED957"); case 60...: Color.aigosAmber; default: Color.aigosAmberDeep }
    }
    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.12), lineWidth: 14)
            Circle().trim(from: 0, to: CGFloat(min(max(score, 0), 100)) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(score)").font(.system(size: 46, weight: .black, design: .rounded)).foregroundStyle(.white)
                Text("/ 100").rounded(12, weight: .semibold).foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(width: 150, height: 150)
    }
}

// MARK: - Shareable 1080×1920 score card

struct ScoreShareCard: View {
    let vehicleName: String
    let score: DrivingScore
    let efficiency: String

    var body: some View {
        VStack(spacing: 36) {
            Spacer(minLength: 80)
            Text("MY DRIVING SCORE").font(.system(size: 58, weight: .black, design: .rounded)).foregroundStyle(.white)
            ZStack {
                Circle().stroke(.white.opacity(0.25), lineWidth: 34)
                Circle().trim(from: 0, to: CGFloat(min(max(score.total, 0), 100)) / 100)
                    .stroke(.white, style: StrokeStyle(lineWidth: 34, lineCap: .round)).rotationEffect(.degrees(-90))
                Text("\(score.total)").font(.system(size: 150, weight: .black, design: .rounded)).foregroundStyle(.white)
            }
            .frame(width: 420, height: 420)
            Text(score.label).font(.system(size: 56, weight: .black, design: .rounded)).foregroundStyle(.white)
            Text("\(vehicleName) · \(efficiency)")
                .font(.system(size: 40, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.9))
            Spacer()
            MascotView(size: 190)
            Text("Made with aigos 🇵🇭").font(.system(size: 40, weight: .bold, design: .rounded)).foregroundStyle(.white)
            Spacer(minLength: 80)
        }
        .frame(width: 1080, height: 1920)
        .background(LinearGradient(colors: [Color(hex: "#F5C97A"), Color(hex: "#C4793A")],
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
    }
}
