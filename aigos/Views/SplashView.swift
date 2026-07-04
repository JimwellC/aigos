//
//  SplashView.swift
//  aigos
//
//  Animated welcome shown after the static launch screen, before the app UI.
//  Mascot springs in, "aigos" and the tagline fade in. Returning users auto-
//  advance in ~1.8s; first-launch users get a "Get Started" CTA. Kept under 2s.
//

import SwiftUI

struct SplashView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    let onFinish: () -> Void

    @State private var mascotIn = false
    @State private var titleIn = false
    @State private var taglineIn = false
    @State private var ctaIn = false

    private var isFirstLaunch: Bool { !hasOnboarded }

    var body: some View {
        ZStack {
            AigosBackground()
            // Dark overlay on the bottom half so the wordmark stays readable.
            LinearGradient(colors: [.clear, .black.opacity(0.35)], startPoint: .center, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                // Mascot takes the top ~60%.
                MascotView(size: 168, floating: true)
                    .scaleEffect(mascotIn ? 1.0 : 0.8)
                    .opacity(mascotIn ? 1 : 0)

                Spacer(minLength: 0)

                // Wordmark + tagline in the bottom ~40%.
                VStack(spacing: Space.sm) {
                    Text("aigos")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .opacity(titleIn ? 1 : 0)
                    Text("Know your fuel cost before every trip.")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .opacity(taglineIn ? 1 : 0)
                }

                if isFirstLaunch {
                    PrimaryButton(title: "Get Started  →") { finish() }
                        .opacity(ctaIn ? 1 : 0)
                        .disabled(!ctaIn)
                        .padding(.top, Space.xl)
                }

                Spacer().frame(height: isFirstLaunch ? Space.xl : Space.xxl)
            }
            .padding(.horizontal, Space.screen)
        }
        .onAppear(perform: animate)
    }

    private func animate() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { mascotIn = true }
        withAnimation(.easeOut(duration: 0.4).delay(0.3)) { titleIn = true }
        withAnimation(.easeOut(duration: 0.4).delay(0.6)) { taglineIn = true }
        if isFirstLaunch {
            withAnimation(.easeOut(duration: 0.4).delay(1.0)) { ctaIn = true }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { finish() }
        }
    }

    private func finish() {
        onFinish()
    }
}
