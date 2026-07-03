//
//  OnboardingView.swift
//  aigos
//
//  First-launch flow (Section 12) — goal: first calculation in under 90 seconds.
//  Welcome → Add vehicle → Driving style → Prices. No account, no email, no cloud.
//  Creates the first VehicleProfile + DrivingProfile, then flips `hasOnboarded`.
//

import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \VehicleProfile.createdAt) private var vehicles: [VehicleProfile]
    @Query private var prices: [FuelPriceCache]
    @AppStorage("fuelUnit") private var fuelUnit: FuelUnit = .kmPerL

    @Binding var hasOnboarded: Bool

    @State private var step = 0

    // Vehicle
    @State private var name = "My Car"
    @State private var type: VehicleType = .car
    @State private var fuelType: FuelType = .ron95
    @State private var efficiencyText = ""

    // Driving style
    @State private var highwayChoice = 2      // 0..3 -> 70/90/110/130
    @State private var acChoice = 0           // 0 always, 1 sometimes, 2 rarely
    @State private var roadChoice: RoadType = .highway

    private let highwaySpeeds: [Double] = [70, 90, 110, 130]

    private var efficiency: Double? {
        Double(efficiencyText.trimmingCharacters(in: .whitespaces))
    }

    var body: some View {
        ZStack {
            AigosBackground()

            VStack(spacing: Space.lg) {
                ProgressDots(count: 4, index: step)
                    .padding(.top, Space.xl)

                Group {
                    switch step {
                    case 0: welcome
                    case 1: addVehicle
                    case 2: drivingStyle
                    default: pricesIntro
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
            .padding(.horizontal, Space.screen)
            .padding(.bottom, Space.xl)
        }
    }

    // MARK: - Screen 1

    private var welcome: some View {
        VStack(spacing: Space.lg) {
            Spacer()
            MascotView(size: 160)
            Text("aigos")
                .rounded(44, weight: .bold)
                .foregroundStyle(.white)
            Text("Know your exact fuel cost before every trip.")
                .rounded(18, weight: .medium)
                .foregroundStyle(Color.aigosTextSecondary)
                .multilineTextAlignment(.center)
            Spacer()
            PrimaryButton(title: "Get started") { advance() }
        }
    }

    // MARK: - Screen 2

    private var addVehicle: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            title("Add your vehicle", subtitle: "So estimates match how it drives.")

            VStack(alignment: .leading, spacing: Space.md) {
                FieldLabel("Name")
                GlassField(placeholder: "My Car", text: $name, autocap: .words)

                FieldLabel("Type")
                PillRow(items: VehicleType.allCases, selection: $type) { $0.label }

                FieldLabel("Fuel type")
                PillRow(items: FuelType.allCases, selection: $fuelType) { $0.label }

                FieldLabel("Efficiency (\(fuelUnit.label))")
                GlassField(placeholder: fuelUnit.defaultInput, text: $efficiencyText, keyboard: .decimalPad)
                    .onAppear { if efficiencyText.isEmpty { efficiencyText = fuelUnit.defaultInput } }
            }
            .padding(Space.md)
            .glassCard()

            Spacer()
            PrimaryButton(title: "Save vehicle", enabled: canSaveVehicle) { advance() }
        }
    }

    private var canSaveVehicle: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (efficiency ?? 0) > 0
    }

    // MARK: - Screen 3

    private var drivingStyle: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            title("Your driving style", subtitle: "Let me learn how you drive for a smarter estimate.")

            MascotBubble(text: "Quick 3 taps and I'll nail your estimate 👇")

            ScrollView {
                VStack(spacing: Space.md) {
                    QuestionCard(question: "How fast on the highway?",
                                 options: ["Under 80", "80–100", "100–120", "Over 120"],
                                 selection: $highwayChoice)
                        .staggeredAppear(index: 0, delayStep: 0.12)
                    QuestionCard(question: "Do you use aircon?",
                                 options: ["Almost always", "Sometimes", "Rarely"],
                                 selection: $acChoice)
                        .staggeredAppear(index: 1, delayStep: 0.12)
                    QuestionCard(question: "Usual road?",
                                 options: RoadType.allCases.map(\.label),
                                 selection: Binding(
                                    get: { RoadType.allCases.firstIndex(of: roadChoice) ?? 0 },
                                    set: { roadChoice = RoadType.allCases[$0] }
                                 ))
                        .staggeredAppear(index: 2, delayStep: 0.12)
                }
            }
            .scrollIndicators(.hidden)

            PrimaryButton(title: "Looks good!") { advance() }
        }
    }

    // MARK: - Screen 4

    private var pricesIntro: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            title("Fuel prices", subtitle: "Updated weekly. Edit any price before calculating.")

            VStack(spacing: Space.sm) {
                ForEach(sortedPrices) { price in
                    HStack {
                        Text(price.fuelType.label)
                            .rounded(16, weight: .medium)
                            .foregroundStyle(.white)
                        Spacer()
                        Text(price.pricePHP.phpString)
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.aigosAmber)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, Space.md)
                }
            }
            .padding(.vertical, Space.sm)
            .glassCard()

            Spacer()
            PrimaryButton(title: "Start calculating") { finish() }
        }
    }

    private var sortedPrices: [FuelPriceCache] {
        let order = Dictionary(uniqueKeysWithValues: FuelType.allCases.enumerated().map { ($1, $0) })
        return prices.sorted { (order[$0.fuelType] ?? 0) < (order[$1.fuelType] ?? 0) }
    }

    // MARK: - Shared

    private func title(_ text: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(text)
                .rounded(30, weight: .bold)
                .foregroundStyle(.white)
            Text(subtitle)
                .rounded(16, weight: .medium)
                .foregroundStyle(Color.aigosTextSecondary)
        }
    }

    private func advance() {
        Haptics.tap(.light)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { step += 1 }
    }

    private func finish() {
        Haptics.tap(.medium)
        // Create the first vehicle + its driving profile from the answers. Input
        // is in the user's chosen unit; store canonical km/L.
        let enteredEff = efficiency ?? Double(fuelUnit.defaultInput) ?? 12
        let vehicle = VehicleProfile(
            name: name.trimmingCharacters(in: .whitespaces),
            type: type,
            fuelType: fuelType,
            efficiencyKmL: fuelUnit.kmL(fromDisplay: enteredEff),
            isDefault: true
        )
        let profile = DrivingProfile(vehicleId: vehicle.id)
        profile.avgHighwaySpeedKmh = highwaySpeeds[highwayChoice]
        profile.usesACByDefault = acChoice < 2   // "almost always" or "sometimes" -> on
        profile.defaultRoadType = roadChoice
        vehicle.drivingProfile = profile

        context.insert(vehicle)
        context.insert(profile)
        try? context.save()

        hasOnboarded = true
    }
}

// MARK: - Small components

private struct ProgressDots: View {
    let count: Int
    let index: Int
    var body: some View {
        HStack(spacing: Space.sm) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == index ? Color.aigosAmber : Color.white.opacity(0.35))
                    .frame(width: i == index ? 22 : 8, height: 8)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: index)
            }
        }
    }
}

/// A row of selectable pills bound to an index-less value.
private struct PillRow<T: Hashable & Identifiable>: View {
    let items: [T]
    @Binding var selection: T
    let label: (T) -> String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.sm) {
                ForEach(items) { item in
                    let selected = item == selection
                    Text(label(item))
                        .rounded(14, weight: .semibold)
                        .foregroundStyle(selected ? .white : .aigosTextSecondary)
                        .padding(.horizontal, Space.md)
                        .padding(.vertical, 10)
                        .background(selected ? Color.aigosAmber : Color.white.opacity(0.12), in: Capsule())
                        .onTapGesture {
                            Haptics.tap(.light)
                            selection = item
                        }
                }
            }
        }
    }
}

/// A tap-to-answer question card (Section 14A hybrid interview style).
private struct QuestionCard: View {
    let question: String
    let options: [String]
    @Binding var selection: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(question)
                .rounded(16, weight: .semibold)
                .foregroundStyle(.white)
            FlowPills(options: options, selection: $selection)
        }
        .padding(Space.md)
        .glassCard()
    }
}

private struct FlowPills: View {
    let options: [String]
    @Binding var selection: Int

    var body: some View {
        VStack(spacing: Space.sm) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                let selected = index == selection
                Button {
                    Haptics.tap(.light)
                    selection = index
                } label: {
                    HStack {
                        Text(option)
                            .rounded(15, weight: .medium)
                            .foregroundStyle(selected ? .white : .aigosTextSecondary)
                        Spacer()
                        if selected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, Space.md)
                    .background(selected ? Color.aigosAmber : Color.white.opacity(0.1), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Mascot speech bubble that slides in from the left on appear.
private struct MascotBubble: View {
    let text: String
    @State private var shown = false

    var body: some View {
        HStack(alignment: .center, spacing: Space.sm) {
            MascotView(size: 40)
            Text(text)
                .rounded(15, weight: .medium)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .padding(Space.md)
                .glassCard(cornerRadius: 18)
        }
        .opacity(shown ? 1 : 0)
        .offset(x: shown ? 0 : -70)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { shown = true }
        }
    }
}

/// Placeholder jeepney mascot — a glowing amber badge until real art lands.
struct MascotView: View {
    var size: CGFloat = 120
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.aigosAmber.opacity(0.25))
                .frame(width: size, height: size)
                .blur(radius: 20)
            Image(systemName: "bus.fill")
                .font(.system(size: size * 0.5))
                .foregroundStyle(.white)
                .shadow(color: Color.aigosAmber.opacity(0.8), radius: 16)
        }
        .frame(width: size, height: size)
    }
}
