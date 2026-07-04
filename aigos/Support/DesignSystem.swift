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
    static let aigosGlassFill = Color.white.opacity(0.20)
    static let aigosGlassStroke = Color.white.opacity(0.45)

    // Tab bar
    static let aigosTabBrown = Color(hex: "#6B3A1F")

    // Text (on gradient)
    static let aigosText = Color.white
    static let aigosTextSecondary = Color.white.opacity(0.75)
    static let aigosTextTertiary = Color.white.opacity(0.55)   // readability floor

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

/// Full-screen "warm sunlight through glass" backdrop: a 3-stop amber gradient
/// with four soft glowing bokeh orbs for real depth. `variant` (one per tab)
/// shifts the orb positions so no two screens look identical.
struct AigosBackground: View {
    var variant: Int = 0

    /// When set, the waving jeepney peeks in from the bottom-trailing corner at
    /// this (x, y) offset — a subtle brand watermark behind the content. It rides
    /// in the orb overlay so its sub-screen size can't inflate the layout (same
    /// reasoning as the bokeh orbs). Only the main tab roots opt in.
    var mascotPeek: CGSize? = nil

    private struct Orb { let color: Color; let size: CGFloat; let blur: CGFloat }

    /// The four glowing orbs. Tighter blur keeps them as defined circles; the
    /// warm orbs use a near-white gold so they read against the amber gradient.
    private static let goldGlow = Color(hex: "#FFE8B8")
    private let orbKinds: [Orb] = [
        Orb(color: .white.opacity(0.22),         size: 380, blur: 45),
        Orb(color: goldGlow.opacity(0.30),       size: 280, blur: 35),   // near-white gold
        Orb(color: .white.opacity(0.15),         size: 180, blur: 25),
        Orb(color: goldGlow.opacity(0.20),       size: 450, blur: 60),   // near-white gold, extra-soft
    ]

    /// Per-screen (x, y) offsets from centre for the four orbs above.
    private static let positions: [[(CGFloat, CGFloat)]] = [
        [(-120, -280), (150,   40), (-110,  320), ( 150,  360)],  // 0 Calculate: top-left + bottom-right
        [( 130, -290), (-140,   40), ( 120,  300), (-150,  370)],  // 1 History:   top-right + bottom-left
        [(   0, -300), (150,  120), (-120, -150), ( 150,  360)],  // 2 Saved:     top-centre + bottom-right
        [(  20, -300), (-140,   70), ( 130, -170), (-150,  360)],  // 3 Prices:    top-centre + bottom-left
        [( 140, -290), (-130,   30), ( 120,  320), (   0,  380)],  // 4 Settings:  top-right + bottom-centre
    ]

    var body: some View {
        let pos = Self.positions[variant % Self.positions.count]
        // The gradient is the primary (screen-sized) view; the orbs ride in an
        // overlay so their sub-screen-width sizes can't inflate the layout and
        // push sibling content off-screen.
        return LinearGradient(
            stops: [
                .init(color: Color.aigosBGTop, location: 0.0),     // #F5C97A light amber
                .init(color: Color.aigosAmber, location: 0.5),     // #E9A84C pure amber
                .init(color: Color.aigosBGBottom, location: 1.0),  // #C4793A deep amber
            ],
            startPoint: .top, endPoint: .bottom
        )
        .overlay {
            ZStack {
                ForEach(Array(orbKinds.enumerated()), id: \.offset) { i, orb in
                    Circle()
                        .fill(orb.color)
                        .frame(width: orb.size, height: orb.size)
                        .blur(radius: orb.blur)
                        .offset(x: pos[i].0, y: pos[i].1)
                }

                if let peek = mascotPeek {
                    Image("MascotWave")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 300)
                        .opacity(0.20)
                        .offset(x: peek.width, y: peek.height)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Glass card

private struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = Radius.md

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return content
            .background {
                shape
                    .fill(.ultraThinMaterial)             // real frosted blur of what's behind
                    .overlay(shape.fill(Color.white.opacity(0.12)))  // warm glass tint
            }
            .clipShape(shape)
            .overlay(shape.stroke(Color.aigosGlassStroke, lineWidth: 1.5))
            .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 8)
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
            .rounded(18, weight: .bold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(
                Capsule().fill(
                    LinearGradient(
                        colors: enabled
                            ? [Color.aigosAmberLight, Color.aigosAmber, Color.aigosAmberDeep]
                            : [Color.aigosAmber.opacity(0.4), Color.aigosAmberDeep.opacity(0.4)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
            )
            .shadow(color: Color.aigosAmber.opacity(enabled ? 0.5 : 0), radius: 16, x: 0, y: 8)
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
        TextField("", text: $text, prompt: Text(placeholder).foregroundColor(Color.white.opacity(0.6)))
            .rounded(17, weight: .medium)
            .foregroundStyle(.white.opacity(0.95))
            .tint(.white)
            .keyboardType(keyboard)
            .textInputAutocapitalization(autocap)
            .padding(.horizontal, Space.md)
            .padding(.vertical, 14)
            .background(Color.black.opacity(0.12))   // darker glass so text has contrast
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.4), lineWidth: 1)
            )
    }
}

// MARK: - Pill selectors

/// A wrapping flow layout — places subviews left-to-right and wraps to a new line
/// when the next one won't fit. Lets all pill options stay visible (no h-scroll).
struct FlowLayout: Layout {
    var spacing: CGFloat = Space.sm

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? max(0, x - spacing) : maxWidth, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

extension View {
    /// The one true selectable-pill chrome. Selected = vivid amber solid fill with
    /// a soft top inner-shadow for depth. Unselected = high-contrast glass: white
    /// 0.25 fill + a **white 0.6 border @ 1.5** so it always reads on amber. Pair
    /// with white (opacity 1.0) text — `.bold` when selected, else `.semibold`.
    func pillStyle(selected: Bool) -> some View {
        self
            .background(Capsule().fill(selected ? Color.aigosAmber : Color.white.opacity(0.15)))
            .overlay {
                if selected {
                    // Soft inner shadow along the top edge for depth.
                    Capsule()
                        .stroke(Color.black.opacity(0.22), lineWidth: 3)
                        .blur(radius: 2.5)
                        .offset(y: 1.5)
                        .mask(Capsule())
                } else {
                    Capsule().strokeBorder(Color.white.opacity(0.7), lineWidth: 2.0)
                }
            }
    }
}

/// A wrapping row of selectable pills — amber when selected, glass otherwise.
struct SelectablePillFlow<T: Hashable & Identifiable>: View {
    let items: [T]
    @Binding var selection: T
    let label: (T) -> String

    var body: some View {
        FlowLayout(spacing: Space.sm) {
            ForEach(items) { item in
                let selected = item == selection
                Text(label(item))
                    .rounded(14, weight: selected ? .bold : .semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Space.md)
                    .padding(.vertical, 10)
                    .pillStyle(selected: selected)
                    .onTapGesture {
                        selection = item
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Small building blocks

/// Uppercased, tracked section header (size 13, semibold, white 0.75, kern 2.0).
struct FieldLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .kerning(2.0)
            .foregroundStyle(Color.white.opacity(0.85))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A white SF Symbol inside a small dark-amber rounded square — the Settings/list
/// row icon style. White always reads on the amber background; the tile carries
/// the colour instead of the glyph.
struct SettingsIcon: View {
    let systemName: String
    var tile: Color = Color(hex: "#8B4A1A")
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(tile, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

extension Text {
    /// Large premium screen title (size 34, black, tracked, pure white, caps).
    func screenTitle() -> some View {
        self.font(.system(size: 34, weight: .black, design: .rounded))
            .kerning(1.5)
            .foregroundStyle(.white)
    }
}

// MARK: - Haptics

enum Haptics {
    @MainActor static func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    @MainActor static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    @MainActor static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
