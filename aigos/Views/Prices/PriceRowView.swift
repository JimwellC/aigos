//
//  PriceRowView.swift
//  aigos
//
//  One editable fuel-price row on glass. Committing an edit stamps it user-updated.
//

import SwiftUI

struct PriceRowView: View {
    @Bindable var price: FuelPriceCache
    var onCommit: () -> Void

    @State private var text: String = ""

    var body: some View {
        HStack {
            Text(price.fuelType.label)
                .rounded(16, weight: .medium)
                .foregroundStyle(.white)
            if price.updatedBy == "user" {
                Image(systemName: "pencil")
                    .font(.caption2)
                    .foregroundStyle(Color.aigosTextTertiary)
            }
            Spacer()
            Text("PHP")
                .rounded(14)
                .foregroundStyle(Color.aigosTextSecondary)
            TextField("0.00", text: $text)
                .font(.system(size: 17, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.aigosAmber)
                .tint(Color.aigosAmber)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 84)
                .onChange(of: text) { _, _ in commit() }
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, 14)
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
    }
}
