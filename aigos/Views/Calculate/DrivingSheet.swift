//
//  DrivingSheet.swift
//  aigos
//
//  The "How you'll drive" editor, presented as a bottom sheet. All driving-profile
//  options as amber-selected glass pills; edits apply live via bindings, so the
//  Calculate summary row updates the moment the sheet is dismissed (drag down, the
//  X, or the Done button).
//

import SwiftUI

struct DrivingSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var highwaySpeed: Double
    @Binding var citySpeed: Double
    @Binding var acUsage: ACUsage
    @Binding var roadType: RoadType
    @Binding var traffic: TrafficCondition
    @Binding var load: VehicleLoad
    @Binding var rushHour: Bool
    @Binding var fuelLevel: FuelLevel
    @Binding var weather: WeatherCondition
    @Binding var roadSurface: RoadSurface

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    section("Speed") {
                        subLabel("Highway")
                        bucketPills([("Under 80", 70), ("80–100", 90), ("100–120", 110), ("120+", 130)],
                                    value: $highwaySpeed)
                        subLabel("City").padding(.top, 12)
                        bucketPills([("Slow", 25), ("Normal", 40), ("Fast", 60)], value: $citySpeed)
                    }

                    section("Air conditioning") {
                        SelectablePillFlow(items: ACUsage.allCases, selection: $acUsage) { $0.label }
                    }

                    section("Road type") {
                        SelectablePillFlow(items: RoadType.allCases, selection: $roadType) { roadLabel($0) }
                    }

                    section("Traffic") {
                        SelectablePillFlow(items: TrafficCondition.allCases, selection: $traffic) { $0.label }
                        rushHourToggle
                    }

                    section("Passengers & load") {
                        SelectablePillFlow(items: VehicleLoad.allCases, selection: $load) { loadLabel($0) }
                    }

                    section("Weather") {
                        SelectablePillFlow(items: WeatherCondition.allCases, selection: $weather) { "\($0.emoji) \($0.label)" }
                    }

                    section("Road surface") {
                        SelectablePillFlow(items: RoadSurface.allCases, selection: $roadSurface) { $0.label }
                    }

                    section("Fuel level") {
                        SelectablePillFlow(items: FuelLevel.allCases, selection: $fuelLevel) { $0.label }
                    }
                }
                .padding(.horizontal, Space.screen)
                .padding(.bottom, Space.lg)
            }
            .scrollIndicators(.hidden)

            doneButton
        }
        // Rush hour on a city road → suggest Heavy traffic (user can still change).
        .onChange(of: rushHour) { _, on in if on, roadType == .city { traffic = .heavy } }
        .onChange(of: roadType) { _, rt in if rushHour, rt == .city { traffic = .heavy } }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("HOW YOU'LL DRIVE")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .kerning(1.0)
                        .foregroundStyle(.white)
                    Text("Adjustments affect your fuel estimate")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }

            Divider()
                .overlay(Color.white.opacity(0.2))
                .padding(.top, Space.md)
        }
        .padding(.horizontal, Space.screen)
        .padding(.top, Space.md)
    }

    private var rushHourToggle: some View {
        Toggle(isOn: $rushHour) {
            Text("Rush hour (7–9 AM, 5–8 PM)")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
        }
        .tint(Color.aigosAmber)
        .padding(.vertical, 12)
        .padding(.top, 8)
    }

    private var doneButton: some View {
        Button {
            dismiss()
        } label: {
            Text("Done")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    Capsule().fill(
                        LinearGradient(colors: [Color.aigosBGTop, Color.aigosBGBottom],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                )
                .shadow(color: Color.aigosAmber.opacity(0.45), radius: 16, x: 0, y: 6)
        }
        .buttonStyle(PressableStyle())
        .padding(.horizontal, Space.screen)
        .padding(.top, 20)
        .padding(.bottom, Space.lg)
    }

    // MARK: - Building blocks

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .kerning(2.0)
                .foregroundStyle(.white.opacity(0.7))
                .padding(.bottom, 10)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 20)
    }

    private func subLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.75))
            .padding(.bottom, 8)
    }

    /// Pills that map to a representative speed; the nearest bucket is selected.
    private func bucketPills(_ buckets: [(String, Double)], value: Binding<Double>) -> some View {
        let current = buckets.min { abs($0.1 - value.wrappedValue) < abs($1.1 - value.wrappedValue) }?.1
        return FlowLayout(spacing: Space.sm) {
            ForEach(buckets, id: \.1) { item in
                pill(item.0, selected: item.1 == current) {
                    value.wrappedValue = item.1
                }
            }
        }
    }

    private func pill(_ text: String, selected: Bool, _ action: @escaping () -> Void) -> some View {
        Text(text)
            .rounded(14, weight: selected ? .bold : .semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, Space.md)
            .padding(.vertical, 10)
            .pillStyle(selected: selected)
            .onTapGesture(perform: action)
    }

    private func roadLabel(_ rt: RoadType) -> String {
        switch rt {
        case .highway: "Highway (NLEX/SLEX)"
        case .city: "City roads"
        case .mountain: "Mountain"
        case .mixed: "Mixed"
        }
    }

    private func loadLabel(_ l: VehicleLoad) -> String {
        switch l {
        case .light: "Driver only"
        case .moderate: "2–3 passengers"
        case .full: "Full load"
        case .cargo: "With cargo"
        }
    }
}
