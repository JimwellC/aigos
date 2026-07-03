//
//  PriceRowView.swift
//  aigos
//
//  One editable fuel-price row. Committing an edit stamps it as user-updated.
//

import SwiftUI

struct PriceRowView: View {
    @Bindable var price: FuelPriceCache
    var onCommit: () -> Void

    @State private var text: String = ""

    var body: some View {
        HStack {
            Text(price.fuelType.label)
            Spacer()
            Text("PHP")
                .foregroundStyle(.secondary)
            TextField("0.00", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 90)
                .monospacedDigit()
                .onSubmit(commit)
            if price.updatedBy == "user" {
                Image(systemName: "pencil")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .onAppear { text = price.pricePHP.oneDecimal }
        .onChange(of: text) { _, _ in commit() }
    }

    private func commit() {
        guard let value = Double(text.trimmingCharacters(in: .whitespaces)),
              value > 0, value != price.pricePHP else { return }
        price.pricePHP = value
        price.updatedBy = "user"
        price.lastUpdated = Date()
        onCommit()
    }
}
