//
//  DesignSystem.swift
//  aigos
//
//  The single source of truth for the aigos visual language (see UI_GUIDELINES.md
//  and skills/swiftui-design.md). Warm amber gradients, glassmorphism cards, soft
//  bokeh depth, SF Pro Rounded type, amber pill buttons. Every screen builds on
//  `AigosBackground` + glass cards — never plain system backgrounds.
//

import SwiftUI

// MARK: - Colour tokens

extension Color {
    // Primary
    static let aigosAmber = Color(hex: "#E9A84C")       // headers, CTAs, accents
    static let aigosAmberLight = Color(hex: "#F2C27A")  // gradient highlight
    static let aigosAmberDeep = Color(hex: "#C4792A")   // pressed / depth

    // Background gradient stops
    static let aigosBGTop = Color(hex: "#F5C97A")
    static let aigosBGBottom = Color(hex: "#C4793A")
    static let aigosTabTop = Color(hex: "#C4793A")
    static let aigosTabBottom = Color(hex: "#8B4A1A")

    // Glass
    static let aigosGlassFill = Color.white.opacity(0.18)
    static let aigosGlassStroke = Color.white.opacity(0.35)

    // Text (on gradient)
    static let aigosText = Color.white
    static let aigosTextSecondary = Color.white.opacity(0.75)
    static let aigosTextTertiary = Color.white.opacity(0.50)

    /// Hex-string initializer (per the design guidelines), supporting #RGB, #RRGGBB
    /// and #AARRGGBB.
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleaned.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Spacing / radii scale

enum Space {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
    static let screen: CGFloat = 24     // horizontal screen padding
}

enum Radius {
    static let sm: CGFloat = 12
    static let md: CGFloat = 20
    static let lg: CGFloat = 28
}

// MARK: - Background

/// Full-screen warm amber gradient with soft bokeh depth. The base layer of every
/// main screen.
struct AigosBackground: View {
    var deep: Bool = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: deep
                    ? [Color.aigosAmberDeep, Color(hex: "#8B4A1A")]
                    : [Color.aigosBGTop, Color.aigosBGBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: -80, y: -120)

            Circle()
                .fill(Color.aigosAmber.opacity(0.15))
                .frame(width: 200, height: 200)
                .blur(radius: 40)
                .offset(x: 100, y: 200)
        }
    }
}

// MARK: - Glass card

private struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = Radius.md

    func body(content: Content) -> some View {
        content
            .background(Color.aigosGlassFill)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.aigosGlassStroke, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
    }
}

extension View {
    /// Standard glassmorphism container — semi-transparent, subtle stroke + shadow.
    func glassCard(cornerRadius: CGFloat = Radius.md) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }

    /// Rounded SF Pro type shortcut used across the app.
    func rounded(_ size: CGFloat, weight: Font.Weight = .regular) -> some View {
        font(.system(size: size, weight: weight, design: .rounded))
    }
}

// MARK: - Buttons

/// Primary CTA — solid amber pill with an amber glow.
struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.sm) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .rounded(17, weight: .semibold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.aigosAmber.opacity(enabled ? 1 : 0.4))
            .clipShape(Capsule())
            .shadow(color: Color.aigosAmber.opacity(enabled ? 0.4 : 0), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
    }
}

/// Secondary CTA — glass pill with a white stroke.
struct SecondaryButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.sm) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .rounded(17, weight: .medium)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.aigosGlassFill)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Inputs

/// Glass text field styled for gradient backgrounds.
struct GlassField: View {
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var autocap: TextInputAutocapitalization = .sentences

    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundColor(Color.aigosTextTertiary))
            .rounded(17, weight: .medium)
            .foregroundStyle(.white)
            .tint(.white)
            .keyboardType(keyboard)
            .textInputAutocapitalization(autocap)
            .padding(.horizontal, Space.md)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - Small building blocks

/// Uppercased tracked label used above inputs and as section headers.
struct FieldLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .rounded(13, weight: .semibold)
            .kerning(1.2)
            .foregroundStyle(Color.aigosTextTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Haptics

enum Haptics {
    @MainActor static func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}
