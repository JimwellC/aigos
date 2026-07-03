//
//  PriceRowView.swift
//  aigos
//
//  One fuel-price row: a per-grade colour bar + name on the left, the price on the
//  right. Tap the row to edit inline — the price becomes a decimal field with an
//  amber edit highlight and Save/Cancel in the keyboard toolbar. No navigation.
//

import SwiftUI

struct PriceRowView: View {
    @Bindable var price: FuelPriceCache
    var startEditing = false
    var onCommit: () -> Void

    @State private var text = ""
    @State private var isEditing = false
    @State private var pulse = false
    @FocusState private var focused: Bool

    private var priceString: String { String(format: "%.2f", price.pricePHP) }

    var body: some View {
        HStack(spacing: Space.md) {
            Capsule()
                .fill(price.fuelType.accentColor)
                .frame(width: 4, height: 28)
                .shadow(color: price.fuelType.accentColor.opacity(0.6), radius: 4)

            Text(price.fuelType.label)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if price.updatedBy == "user" && !isEditing {
                Image(systemName: "pencil")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer(minLength: Space.sm)

            Text("PHP")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))

            if isEditing {
                TextField("0.00", text: $text)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .tint(.white)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 92)
                    .focused($focused)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Button("Cancel") { cancel() }
                                .tint(.white)
                            Spacer()
                            Button("Save") { focused = false }
                                .bold()
                                .tint(Color.aigosAmberDeep)
                        }
                    }
            } else {
                Text(priceString)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .frame(width: 92, alignment: .trailing)
            }
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isEditing ? Color.aigosAmber.opacity(0.16)
                                : (pulse ? Color.aigosAmber.opacity(0.28) : Color.clear))
        )
        .overlay(alignment: .leading) {
            if isEditing {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.aigosAmber)
                    .frame(width: 3)
                    .shadow(color: Color.aigosAmber.opacity(0.9), radius: 6)
                    .padding(.vertical, 4)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if !isEditing { startEdit() } }
        .onChange(of: focused) { _, isFocused in
            // Blurring (Save, or tapping elsewhere) commits; Cancel already reset.
            if !isFocused && isEditing {
                commit()
                withAnimation(.easeOut(duration: 0.2)) { isEditing = false }
            }
        }
        .onAppear {
            text = priceString
            if startEditing { startEdit() }
        }
    }

    private func startEdit() {
        Haptics.tap(.light)
        text = priceString
        withAnimation(.easeOut(duration: 0.2)) { isEditing = true }
        focused = true
    }

    private func cancel() {
        text = priceString      // discard → blur-commit becomes a no-op
        focused = false
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
