//
//  Animations.swift
//  aigos
//
//  Reusable native-SwiftUI animation primitives used across the app. No
//  third-party libraries — just Animatable, GeometryEffect, ButtonStyle, and
//  ViewModifier.
//

import SwiftUI

/// Fade + slide-up on appear, optionally staggered by index for list items.
struct StaggeredAppear: ViewModifier {
    var index: Int = 0
    var delayStep: Double = 0.05
    var yOffset: CGFloat = 14
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : yOffset)
            .onAppear {
                withAnimation(.easeOut(duration: 0.3).delay(Double(index) * delayStep)) {
                    shown = true
                }
            }
    }
}

extension View {
    func staggeredAppear(index: Int = 0, delayStep: Double = 0.05, yOffset: CGFloat = 14) -> some View {
        modifier(StaggeredAppear(index: index, delayStep: delayStep, yOffset: yOffset))
    }
}

/// Tactile press: scale down while pressed, spring back on release.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// One-shot horizontal shake (wiggle) — drive `animatableData` 0 → 1 to play it.
struct Shake: GeometryEffect {
    var amount: CGFloat = 8
    var shakes: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(
            translationX: amount * sin(animatableData * .pi * shakes), y: 0
        ))
    }
}
