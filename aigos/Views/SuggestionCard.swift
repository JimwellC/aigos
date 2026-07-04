//
//  SuggestionCard.swift
//  aigos
//
//  A single fuel-saving tip rendered as a glass card (Feature 4). Used in the
//  Driving Insights dashboard (not dismissable) and on the Calculate screen
//  (dismissable — pass an onDismiss).
//

import SwiftUI

struct SuggestionCard: View {
    let suggestion: Suggestion
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: Space.md) {
            Image(systemName: suggestion.icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.aigosAmber)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(suggestion.title)
                    .rounded(15, weight: .bold).foregroundStyle(.white)
                Text(suggestion.detail)
                    .rounded(12).foregroundStyle(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if let onDismiss {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}
