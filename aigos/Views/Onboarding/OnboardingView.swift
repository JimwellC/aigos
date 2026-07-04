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
        if let s = DebugSupport.onboardingStep {
            _step = State(initialValue: s)
            // Debug screenshots of the vehicle step expect the form, not search.
            if s == 1 { _vehicleSearching = State(initialValue: false) }
        }
        #endif
    }

    // Vehicle
    @State private var name = "My Car"
    @State private var type: VehicleType = .car
    @State private var fuelType: FuelType = .premium95
    @State private var efficiencyText = ""
    @State private var tankText = ""
    @State private var yearText = ""
    @State private var vehicleSearching = true    // database search step before the form
    @State private var selectedModel: String?

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
                // The welcome hero (step 0) is full-bleed with no progress bar;
                // the progress bar tracks the three form steps that follow.
                if step > 0 {
                    ProgressBar(progress: Double(step) / 3)
                        .padding(.top, Space.xl)
                        .padding(.horizontal, Space.lg)
                }

                Group {
                    switch step {
                    case 0: welcome
                    case 1: addVehicle
                    case 2: drivingStyle
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
        case 0: "hand.wave.fill"
        case 1: "car.fill"
        case 2: "steeringwheel"
        default: "fuelpump.fill"
        }
    }


    // MARK: - Screen 0 — Welcome

    /// Large, centered jeepney hero (the square app-icon mascot) that opens the
    /// flow, gently bobbing above the welcome copy.
    private var welcome: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 60)

            MascotView(size: 220, floating: true, imageName: "Mascot",
                       floatDistance: 8, floatDuration: 2.5)

            Spacer().frame(height: 40)

            VStack(spacing: Space.sm) {
                Text("Welcome to aigos")
                    .rounded(30, weight: .bold)
                    .foregroundStyle(.white)
                Text("Know your fuel cost before every trip.\nOffline. No login. Sakto para sa Pinoy roads.")
                    .rounded(16, weight: .medium)
                    .foregroundStyle(Color.aigosTextSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Space.screen)

            Spacer(minLength: 0)

            PrimaryButton(title: "Get Started  →", action: advance)
                .padding(.horizontal, Space.screen)
                .padding(.top, Space.sm)
                .padding(.bottom, Space.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }


    // MARK: - Screen 1 — Add vehicle

    @ViewBuilder
    private var addVehicle: some View {
        if vehicleSearching {
            VehicleSearchStep(
                heading: "What's your vehicle?",
                selectedDisplayName: selectedModel,
                onSelect: { applyVehicleEntry($0); withAnimation { vehicleSearching = false } },
                onManual: { _ in applyVehicleManual(); withAnimation { vehicleSearching = false } }
            )
        } else {
            vehicleForm
        }
    }

    private var vehicleForm: some View {
        screen(cta: "Save vehicle", ctaEnabled: canSaveVehicle, action: advance) {
            title("Add your vehicle", subtitle: "So estimates match how it drives.")

            Button {
                withAnimation { vehicleSearching = true }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                    Text(selectedModel != nil ? "Change vehicle model" : "Search the vehicle database")
                }
                .rounded(14, weight: .semibold)
                .foregroundStyle(.white)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.12), in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: Space.md) {
                FieldLabel("Name")
                GlassField(placeholder: "My Car", text: $name, autocap: .words)

                FieldLabel("Type")
                SelectablePillFlow(items: VehicleType.allCases, selection: $type) { $0.label }

                FieldLabel("Fuel type")
                SelectablePillFlow(items: FuelType.allCases, selection: $fuelType) { $0.label }

                FieldLabel("Efficiency (\(fuelUnit.label))")
                GlassField(placeholder: fuelUnit.defaultInput, text: $efficiencyText, keyboard: .decimalPad)
                    .onAppear { if efficiencyText.isEmpty { efficiencyText = fuelUnit.defaultInput } }

                FieldLabel("Tank size (L)")
                GlassField(placeholder: "\(Int(type.typicalTankLiters))", text: $tankText, keyboard: .decimalPad)

                FieldLabel("Year (optional)")
                GlassField(placeholder: "e.g. 2018", text: $yearText, keyboard: .numberPad)
                Text("We use this to estimate real-world efficiency based on engine wear.")
                    .rounded(12)
                    .foregroundStyle(Color.aigosTextTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Space.md)
            .glassCard()
        }
    }

    private var canSaveVehicle: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (efficiency ?? 0) > 0
    }

    /// Tank capacity (L) — typed value, else the vehicle type's typical tank.
    private var tankCapacityL: Double {
        let typed = Double(tankText.trimmingCharacters(in: .whitespaces)) ?? 0
        return typed > 0 ? typed : type.typicalTankLiters
    }

    private func applyVehicleEntry(_ entry: VehicleEntry) {
        selectedModel = entry.displayName
        name = entry.model
        type = entry.vehicleType
        fuelType = entry.fuelType
        efficiencyText = fuelUnit.displayValue(fromKmL: entry.kmL).oneDecimal
        tankText = entry.tankCapacityL.clean
    }

    private func applyVehicleManual() {
        selectedModel = nil
        name = ""
        if efficiencyText.isEmpty { efficiencyText = fuelUnit.defaultInput }
        tankText = ""
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
        withAnimation(.easeInOut(duration: 0.25)) { step += 1 }
    }

    private func finish() {
        // Create the first vehicle + its driving profile from the answers. Input
        // is in the user's chosen unit; store canonical km/L.
        let enteredEff = efficiency ?? Double(fuelUnit.defaultInput) ?? 12
        let parsedYear = Int(yearText.trimmingCharacters(in: .whitespaces))
        let year = parsedYear.flatMap { (1990...Calendar.current.component(.year, from: Date())).contains($0) ? $0 : nil }
        let vehicle = VehicleProfile(
            name: name.trimmingCharacters(in: .whitespaces),
            type: type,
            fuelType: fuelType,
            efficiencyKmL: fuelUnit.kmL(fromDisplay: enteredEff),
            tankCapacityL: tankCapacityL,
            isDefault: true,
            manufacturingYear: year
        )
        let profile = DrivingProfile()
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
        .animation(.easeOut(duration: 0.25), value: progress)
    }
}

private extension View {
    /// Shared amber/glass pill styling for the driving-style option rows.
    func onboardingPill(selected: Bool) -> some View {
        self.pillStyle(selected: selected)
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
                    selection = index
                } label: {
                    HStack {
                        Text(option)
                            .rounded(15, weight: selected ? .bold : .medium)
                            .foregroundStyle(.white)
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
            withAnimation(.easeOut(duration: 0.25)) { shown = true }
        }
    }
}

/// Jeepney mascot artwork. `floating: true` gives it a gentle up/down bob.
struct MascotView: View {
    var size: CGFloat = 120
    var floating: Bool = false
    var imageName: String = "Mascot"
    var floatDistance: CGFloat = 6
    var floatDuration: Double = 1.8
    @State private var floatUp = false

    var body: some View {
        Image(imageName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.28), radius: size * 0.09, x: 0, y: size * 0.035)
            .offset(y: floating && floatUp ? -floatDistance : 0)
            .onAppear {
                if floating {
                    withAnimation(.easeInOut(duration: floatDuration).repeatForever(autoreverses: true)) { floatUp = true }
                }
            }
    }
}

/// Empty state: centered title + message. The waving jeepney is supplied by the
/// tab's `AigosBackground(mascotPeek:)` watermark, so this view stays text-only
/// to avoid doubling the mascot on empty History/Saved screens.
struct MascotEmptyState: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: Space.sm) {
            Text(title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(message)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
