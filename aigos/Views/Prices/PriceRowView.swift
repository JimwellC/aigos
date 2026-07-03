//
//  PriceRowView.swift
//  aigos
//
//  One editable fuel-price row: amber accent bar + grade name on the left, a
//  large bold WHITE value on the right (never amber-on-amber). Committing an edit
//  stamps it user-updated and pulses the row.
//

import SwiftUI

struct PriceRowView: View {
    @Bindable var price: FuelPriceCache
    var onCommit: () -> Void

    @State private var text: String = ""
    @State private var pulse = false

    var body: some View {
        HStack(spacing: Space.md) {
            RoundedRectangle(cornerRadius: 2)
                .fill(price.fuelType.accentColor)
                .frame(width: 4, height: 32)
                .shadow(color: price.fuelType.accentColor.opacity(0.6), radius: 4)

            Text(price.fuelType.label)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            if price.updatedBy == "user" {
                Image(systemName: "pencil")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer()

            Text("PHP")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
            TextField("0.00", text: $text)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .tint(.white)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 92)
                .onChange(of: text) { _, _ in commit() }

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.35))
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, 14)
        .background(pulse ? Color.aigosAmber.opacity(0.28) : Color.clear)
        // Two-decimal seed formatting so merely displaying a price (e.g. 62.55)
        // never round-trips through a lossy string and marks it "user"-edited.
        .onAppear { text = String(format: "%.2f", price.pricePHP) }
    }

    private func commit() {
        guard let value = Double(text.trimmingCharacters(in: .whitespaces)),
              value > 0, abs(value - price.pricePHP) > 0.001 else { return }
        price.pricePHP = value
        price.updatedBy = "user"
        price.lastUpdated = Date()
        onCommit()
        flashPulse()
    }

    /// Brief amber pulse to confirm an edit landed.
    private func flashPulse() {
        pulse = true
        withAnimation(.easeOut(duration: 0.6)) { pulse = false }
    }
}
