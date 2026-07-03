//
//  AIGateView.swift
//  aigos
//
//  Explains how "Talk to aigos" understands your query and its Apple Intelligence
//  status (Section 13). On unsupported devices the message is reassuring, not a
//  dead end: the offline parser still works, so the feature is never blocked.
//

import SwiftUI

struct AIGateView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AigosBackground()

            VStack(spacing: Space.lg) {
                Spacer()

                Image(systemName: AIAvailability.isAvailable ? "apple.logo" : "cpu")
                    .font(.system(size: 52))
                    .foregroundStyle(.white)
                    .padding(Space.lg)
                    .background(Color.white.opacity(0.12), in: Circle())

                Text(AIAvailability.isAvailable ? "Apple Intelligence" : "On-device understanding")
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
