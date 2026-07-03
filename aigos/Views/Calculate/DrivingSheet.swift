//
//  DrivingSheet.swift
//  aigos
//
//  The "How you'll drive" editor, presented as a bottom sheet. All driving-profile
//  options as amber-selected glass pills; edits apply live via bindings, so the
//  Calculate summary row updates the moment the sheet is dismissed (drag down or
//  the Done button).
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

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    section("Speed") {
                        subLabel("Highway")
                        bucketPills([("Under 80", 70), ("80–100", 90), ("100–120", 110), ("120+", 130)],
                                    value: $highwaySpeed)
                        subLabel("City").padding(.top, 6)
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
                        Toggle(isOn: $rushHour) {
                            Text("Rush hour (7–9 AM, 5–8 PM)")
                                .rounded(15, weight: .medium)
                                .foregroundStyle(.white)
                        }
                        .tint(Color.aigosAmber)
                        .padding(.top, 4)
                    }

                    section("Passengers & load") {
                        SelectablePillFlow(items: VehicleLoad.allCases, selection: $load) { $0.label }
                    }

                    section("Fuel level") {
                        SelectablePillFlow(items: FuelLevel.allCases, selection: $fuelLevel) { $0.label }
                    }
                }
                .padding(.horizontal, Space.screen)
                .padding(.top, Space.md)
                .padding(.bottom, Space.lg)
            }
            .scrollIndicators(.hidden)

            PrimaryButton(title: "Done") {
                Haptics.tap(.medium)
                dismiss()
            }
            .padding(.horizontal, Space.screen)
            .padding(.bottom, Space.lg)
        }
        // Rush hour on a city road → suggest Heavy traffic (user can still change).
        .onChange(of: rushHour) { _, on in if on, roadType == .city { traffic = .heavy } }
        .onChange(of: roadType) { _, rt in if rushHour, rt == .city { traffic = .heavy } }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("HOW YOU'LL DRIVE")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .kerning(1.0)
                    .foregroundStyle(.white)
                Text("Adjustments affect your fuel estimate")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
            }
            Spacer()
            Button {
                Haptics.tap(.light)
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, Space.screen)
        .padding(.top, Space.md)
        .padding(.bottom, Space.sm)
    }

    // MARK: - Building blocks

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            FieldLabel(title)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func subLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.8))
    }

    /// Pills that map to a representative speed; the nearest bucket is selected.
    private func bucketPills(_ buckets: [(String, Double)], value: Binding<Double>) -> some View {
        let current = buckets.min { abs($0.1 - value.wrappedValue) < abs($1.1 - value.wrappedValue) }?.1
        return FlowLayout(spacing: Space.sm) {
            ForEach(buckets, id: \.1) { item in
                pill(item.0, selected: item.1 == current) {
                    Haptics.tap(.light)
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
}
