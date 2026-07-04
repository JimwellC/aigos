//
//  ResultSheet.swift
//  aigos
//
//  The calculation result, presented as a bottom sheet over the Calculate screen:
//  a route header for context, the glassmorphism receipt card (with a count-up
//  cost), and Save / Done actions. Swipe down to dismiss and adjust inputs.
//

import SwiftUI

struct ResultSheet: View {
    let estimate: FuelEstimate
    let finalCost: Double
    let confidence: String?
    let tankLiters: Double?
    let routeTitle: String
    let vehicleName: String
    @Binding var saved: Bool
    let onSave: () -> Void
    let onTrack: () -> Void
    let onDone: () -> Void

    @State private var heroCost: Double = 0

    var body: some View {
        ScrollView {
            VStack(spacing: Space.lg) {
                // Route header — gives the number context (below the drag handle).
                VStack(spacing: 4) {
                    Text(routeTitle)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    Text(vehicleName)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)

                ResultCard(estimate: estimate, heroCost: heroCost,
                           confidence: confidence, tankLiters: tankLiters)

                VStack(spacing: Space.sm) {
                    SecondaryButton(
                        title: saved ? "Saved to routes" : "Save this route",
                        systemImage: saved ? "star.fill" : "star",
                        action: onSave
                    )
                    .disabled(saved)

                    // Track the actual drive to compare estimate vs reality (v1.1).
                    Button(action: onTrack) {
                        HStack(spacing: 8) {
                            Image(systemName: "location.fill")
                            Text("Track This Trip")
                        }
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.aigosAmberDeep)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.aigosAmber, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Text("Keep aigos open while driving to track your trip.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .multilineTextAlignment(.center)

                    PrimaryButton(title: "Done", action: onDone)
                }
            }
            .padding(.horizontal, Space.screen)
            .padding(.top, Space.lg)
            .padding(.bottom, Space.xl)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            heroCost = 0
            // Count-up: the cost springs from 0 as the sheet settles.
            withAnimation(.spring(response: 0.6, dampingFraction: 0.72)) { heroCost = finalCost }
        }
    }
}
