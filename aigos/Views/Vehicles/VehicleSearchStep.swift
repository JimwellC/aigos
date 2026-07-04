//
//  VehicleSearchStep.swift
//  aigos
//
//  Database-first vehicle selection (Add Vehicle / Onboarding step 1). Type to
//  autocomplete against VehicleDatabase (prefix, fuzzy typos, nicknames, and
//  category words like "SUV"); tap a result to auto-fill the form, or fall back
//  to manual entry via "My car is not in the list". The bundled database loads
//  synchronously from the app bundle, so results appear instantly (no spinner).
//

import SwiftUI

struct VehicleSearchStep: View {
    var heading: String = "Search your vehicle"
    /// The currently-chosen model (edit mode) — shown with an amber checkmark.
    var selectedDisplayName: String? = nil
    var onSelect: (VehicleEntry) -> Void
    var onManual: (String) -> Void

    @AppStorage("fuelUnit") private var fuelUnit: FuelUnit = .kmPerL
    @State private var query = ""
    @FocusState private var focused: Bool

    // EVs live in the database for Talk answers, but the trip calculator is
    // petrol/diesel-only, so they aren't selectable when adding a vehicle.
    private var results: [VehicleEntry] { VehicleDatabase.search(query).filter { !$0.isElectric } }
    private var trimmed: String { query.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.md) {
                FieldLabel(heading)
                GlassField(placeholder: "e.g. Vios, Innova, NMAX, Fortuner",
                           text: $query, autocap: .words)
                    .focused($focused)

                if trimmed.isEmpty {
                    Text("Search by make, model, or type — e.g. “Vios”, “Fortuner”, “NMAX”, or “SUV”.")
                        .rounded(13)
                        .foregroundStyle(.white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Space.xs)
                } else if results.isEmpty {
                    Text("No matches for “\(trimmed)”. Try a different spelling, or enter it manually below.")
                        .rounded(14)
                        .foregroundStyle(.white.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(spacing: Space.sm) {
                        ForEach(Array(results.enumerated()), id: \.offset) { _, entry in
                            resultRow(entry)
                        }
                    }
                }

                notListedButton
                    .padding(.top, Space.sm)
            }
            .padding(.horizontal, Space.screen)
            .padding(.vertical, Space.lg)
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear { focused = true }
    }

    private func resultRow(_ entry: VehicleEntry) -> some View {
        Button {
            Haptics.tap(.light)
            onSelect(entry)
        } label: {
            HStack(spacing: Space.md) {
                Text(entry.vehicleType.emoji).font(.system(size: 22))
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.displayName)
                        .rounded(16, weight: .semibold)
                        .foregroundStyle(.white)
                    Text(subtitle(for: entry))
                        .rounded(13)
                        .foregroundStyle(Color.aigosTextSecondary)
                }
                Spacer()
                if selectedDisplayName == entry.displayName {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.aigosAmber)
                        .font(.system(size: 20))
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Color.white.opacity(0.35))
                        .font(.system(size: 13, weight: .semibold))
                }
            }
            .padding(Space.md)
            .glassCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func subtitle(for entry: VehicleEntry) -> String {
        if entry.isElectric {
            return "Electric · \(VehicleDatabase.fmt(entry.kmL)) km/kWh"
        }
        return "\(entry.fuelType.label) · \(fuelUnit.format(kmL: entry.kmL))"
    }

    private var notListedButton: some View {
        Button {
            Haptics.tap(.light)
            UnlistedSearchLog.record(query)   // private, local-only
            onManual(trimmed)
        } label: {
            HStack(spacing: Space.sm) {
                Image(systemName: "square.and.pencil")
                Text("My car is not in the list — enter manually")
            }
            .rounded(14, weight: .medium)
            .foregroundStyle(.white.opacity(0.6))
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.md)
            .background(Color.white.opacity(0.08), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
