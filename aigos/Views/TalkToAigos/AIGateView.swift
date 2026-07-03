//
//  AIGateView.swift
//  aigos
//
//  Explains how "Talk to aigos" understands your query: a natural-language trip
//  assistant that runs entirely on-device, offline, on every iPhone.
//

import SwiftUI

struct AIGateView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AigosBackground()

            VStack(spacing: Space.lg) {
                Spacer()

                Image(systemName: "cpu")
                    .font(.system(size: 52))
                    .foregroundStyle(.white)
                    .padding(Space.lg)
                    .background(Color.white.opacity(0.12), in: Circle())

                Text(AIAvailability.tagline)
                    .rounded(26, weight: .bold)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(AIAvailability.explanation)
                    .rounded(16, weight: .medium)
                    .foregroundStyle(Color.aigosTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.md)

                Label("Works fully offline. Nothing leaves your iPhone.", systemImage: "lock.fill")
                    .rounded(13, weight: .medium)
                    .foregroundStyle(Color.aigosTextTertiary)

                Spacer()

                PrimaryButton(title: "Got it") { dismiss() }
            }
            .padding(.horizontal, Space.screen)
            .padding(.bottom, Space.xl)
        }
    }
}

#Preview {
    AIGateView()
}
