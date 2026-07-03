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

    init(hasOnboarded: Binding<Bool>) {
        self._hasOnboarded = hasOnboarded
        #if DEBUG
        if let s = DebugSupport.onboardingStep { _step = State(initialValue: s) }
        #endif
    }

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
            AigosBackground(variant: step)

            // Large low-opacity SF Symbol texture behind the content. Held inside a
            // flexible Color.clear + .clipped() so its oversized glyph can never
            // drive the ZStack wider than the screen (which shifted content off-edge).
            Color.clear
                .overlay(
                    Image(systemName: bgSymbol)
                        .font(.system(size: 340, weight: .bold))
                        .foregroundStyle(.white.opacity(0.06))
                        .offset(x: 90, y: -30)
                )
                .clipped()
                .allowsHitTesting(false)

            VStack(spacing: Space.md) {
                ProgressBar(progress: Double(step + 1) / 3)
                    .padding(.top, Space.xl)
                    .padding(.horizontal, Space.lg)

                Group {
                    switch step {
                    case 0: addVehicle
                    case 1: drivingStyle
                    default: pricesIntro
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .transition(.opacity)
            }
        }
    }

    /// A screen: scrollable content (inset 24) with a pinned bottom CTA.
    private func screen<Content: View>(cta: String, ctaEnabled: Bool = true,
                                       action: @escaping () -> Void,
                                       @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    content()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Space.screen)
                .padding(.top, Space.md)
                .padding(.bottom, Space.lg)
            }
            .scrollIndicators(.hidden)

            PrimaryButton(title: cta, enabled: ctaEnabled, action: action)
                .padding(.horizontal, Space.screen)
                .padding(.top, Space.sm)
                .padding(.bottom, Space.lg)
        }
    }

    private var bgSymbol: String {
        switch step {
        case 0: "car.fill"
        case 1: "steeringwheel"
        default: "fuelpump.fill"
        }
    }


    // MARK: - Screen 1 — Add vehicle

    private var addVehicle: some View {
        screen(cta: "Save vehicle", ctaEnabled: canSaveVehicle, action: advance) {
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
        }
    }

    private var canSaveVehicle: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (efficiency ?? 0) > 0
    }

    // MARK: - Screen 2 — Driving style

    private var drivingStyle: some View {
        screen(cta: "Looks good!", action: advance) {
            title("Your driving style", subtitle: "Let me learn how you drive for a smarter estimate.")

            MascotBubble(text: "Quick 3 taps and I'll nail your estimate 👇")

            QuestionCard(question: "How fast on the highway?",
                         options: ["Under 80", "80–100", "100–120", "Over 120"],
                         selection: $highwayChoice)
            QuestionCard(question: "Do you use aircon?",
                         options: ["Almost always", "Sometimes", "Rarely"],
                         selection: $acChoice)
            QuestionCard(question: "Usual road?",
                         options: RoadType.allCases.map(\.label),
                         selection: Binding(
                            get: { RoadType.allCases.firstIndex(of: roadChoice) ?? 0 },
                            set: { roadChoice = RoadType.allCases[$0] }
                         ))
        }
    }

    // MARK: - Screen 3 — Prices

    private var pricesIntro: some View {
        screen(cta: "Start calculating", action: finish) {
            title("Fuel prices", subtitle: "Updated weekly. Edit any price before calculating.")

            VStack(spacing: 0) {
                ForEach(Array(sortedPrices.enumerated()), id: \.element.id) { i, price in
                    HStack(spacing: Space.md) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(price.fuelType.accentColor)
                            .frame(width: 4, height: 26)
                        Text(price.fuelType.label)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                        Text("PHP")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                        Text(String(format: "%.2f", price.pricePHP))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, Space.md)
                    if i < sortedPrices.count - 1 {
                        Divider().overlay(Color.white.opacity(0.15))
                    }
                }
            }
            .padding(.vertical, Space.xs)
            .glassCard()
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

/// Amber progress bar that animates its fill across the screen.
private struct ProgressBar: View {
    let progress: Double   // 0…1
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.2))
                Capsule()
                    .fill(LinearGradient(colors: [Color.aigosAmberLight, Color.aigosAmber],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(8, g.size.width * progress))
            }
        }
        .frame(height: 6)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
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
                        .rounded(14, weight: selected ? .bold : .semibold)
                        .foregroundStyle(selected ? .white : .white.opacity(0.8))
                        .padding(.horizontal, Space.md)
                        .padding(.vertical, 10)
                        .background(selected ? Color.aigosAmber : Color.white.opacity(0.18), in: Capsule())
                        .overlay(Capsule().stroke(selected ? Color.clear : Color.white.opacity(0.3), lineWidth: 1))
                        .onTapGesture {
                            Haptics.tap(.light)
                            selection = item
                        }
                }
            }
            .padding(.vertical, 2)   // room for the stroke
        }
    }
}

private extension View {
    /// Shared amber/glass pill styling for the driving-style option rows.
    func onboardingPill(selected: Bool) -> some View {
        self.background(selected ? Color.aigosAmber : Color.white.opacity(0.18), in: Capsule())
            .overlay(Capsule().stroke(selected ? Color.clear : Color.white.opacity(0.3), lineWidth: 1))
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
                            .rounded(15, weight: selected ? .bold : .medium)
                            .foregroundStyle(selected ? .white : .white.opacity(0.8))
                        Spacer()
                        if selected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, Space.md)
                    .onboardingPill(selected: selected)
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

/// Jeepney mascot artwork. `floating: true` gives it a gentle up/down bob.
struct MascotView: View {
    var size: CGFloat = 120
    var floating: Bool = false
    @State private var floatUp = false

    var body: some View {
        Image("Mascot")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.28), radius: size * 0.09, x: 0, y: size * 0.035)
            .offset(y: floating && floatUp ? -6 : 0)
            .onAppear {
                if floating {
                    withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { floatUp = true }
                }
            }
    }
}

/// Full-screen empty state: floating mascot + a friendly title and message.
struct MascotEmptyState: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: Space.lg) {
            MascotView(size: 120, floating: true)
            Text(title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(message)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(Space.xl)
        .frame(maxWidth: .infinity)
    }
}
