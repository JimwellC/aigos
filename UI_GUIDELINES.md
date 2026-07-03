# aigos — UI/UX Guidelines

> Visual reference: Passion Finder app (warm amber gradient, glassmorphism cards, soft bokeh backgrounds)
> These guidelines are FINAL. Apply consistently across all screens.

---

## VISUAL LANGUAGE

### Core Aesthetic
Warm, premium, and softly glowing. Every screen should feel like golden hour on SLEX —
amber light, depth, and calm confidence. Not a utility app. A companion app.

### Mood Reference
- Warm amber gradients (not flat fills — always gradient or frosted)
- Soft bokeh / blurred background depth (like the reference image)
- Glassmorphism cards — semi-transparent, blurred, with subtle border
- Large bold numbers for key results (like the 7.5 score in reference)
- Floating, airy layouts — content breathes, nothing feels cramped

---

## COLOR SYSTEM

```swift
// Primary
let amber: Color = Color(hex: "#E9A84C")          // Headers, CTAs, accents
let amberLight: Color = Color(hex: "#F2C27A")      // Gradient highlight
let amberDeep: Color = Color(hex: "#C4792A")       // Pressed states, depth

// Background
let bgBase: Color = Color(hex: "#FDF6E3")          // Warm cream (light mode base)
let bgGradientTop: Color = Color(hex: "#F5C97A")   // Gradient start (top)
let bgGradientBottom: Color = Color(hex: "#C4793A") // Gradient end (bottom)

// Glass / Card
// Cards use .ultraThinMaterial as a blur base + a white 0.12 tint on top.
let glassWhite: Color = Color.white.opacity(0.20)  // Card tint (higher contrast)
let glassBorder: Color = Color.white.opacity(0.45) // Card stroke, lineWidth 1.5
let glassShadow: Color = Color.black.opacity(0.25) // Card shadow, radius 20, y 8

// Text
let textPrimary: Color = Color.white               // On gradient backgrounds
let textSecondary: Color = Color.white.opacity(0.75)
let textTertiary: Color = Color.white.opacity(0.50)
let textDark: Color = Color(hex: "#2C1A0E")        // On light surfaces

// Result highlight
let resultCost: Color = Color.white                // ESTIMATED COST — always white, bold
let resultAccent: Color = Color(hex: "#E9A84C")    // Amber for key values
```

---

## GRADIENTS

```swift
// Main background gradient (used on Calculate, Onboarding, Talk to aigos)
let backgroundGradient = LinearGradient(
    colors: [Color(hex: "#F5C97A"), Color(hex: "#C4793A")],
    startPoint: .top,
    endPoint: .bottom
)

// Subtle card gradient
let cardGradient = LinearGradient(
    colors: [Color.white.opacity(0.22), Color.white.opacity(0.08)],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

// Tab bar background
let tabGradient = LinearGradient(
    colors: [Color(hex: "#C4793A").opacity(0.95), Color(hex: "#8B4A1A").opacity(0.98)],
    startPoint: .top,
    endPoint: .bottom
)
```

---

## TYPOGRAPHY

```swift
// Display — large result numbers, screen titles
// SF Pro Rounded — warm, friendly, not mechanical
.font(.system(size: 52, weight: .bold, design: .rounded))   // ESTIMATED COST number
.font(.system(size: 34, weight: .bold, design: .rounded))   // Screen titles
.font(.system(size: 28, weight: .semibold, design: .rounded)) // Section headers

// Body
.font(.system(size: 17, weight: .medium, design: .rounded)) // Primary body
.font(.system(size: 15, weight: .regular, design: .rounded)) // Secondary body
.font(.system(size: 13, weight: .regular, design: .rounded)) // Captions, labels

// Monospaced for numbers/values
.font(.system(size: 17, weight: .semibold, design: .monospaced)) // PHP values in breakdown
```

**Rules:**
- Always use `.design: .rounded` — never default or serif
- Screen titles: ALL CAPS with letter spacing (like "PASSION FINDER" in reference)
- Result cost: largest possible, centered, bold, white
- Labels above inputs: small, `.textTertiary`, uppercased

---

## GLASSMORPHISM CARD STYLE

```swift
// Standard glass card — use for all content cards
struct GlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.18))
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.35), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 6)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// Usage
Text("PHP 450.36")
    .modifier(GlassCard())
```

---

## SPACING & LAYOUT

```swift
// Spacing scale
let spaceXS: CGFloat = 4
let spaceSM: CGFloat = 8
let spaceMD: CGFloat = 16
let spaceLG: CGFloat = 24
let spaceXL: CGFloat = 32
let spaceXXL: CGFloat = 48

// Corner radii
let radiusSM: CGFloat = 12   // Small chips, tags
let radiusMD: CGFloat = 20   // Cards, input fields
let radiusLG: CGFloat = 28   // Bottom sheets, large cards
let radiusFull: CGFloat = 999 // Pills, buttons

// Screen padding
let screenPadding: CGFloat = 24  // Horizontal padding on all screens
```

---

## BUTTONS

```swift
// Primary CTA — solid amber, rounded pill
struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(hex: "#E9A84C"))
                .clipShape(Capsule())
                .shadow(color: Color(hex: "#E9A84C").opacity(0.4), radius: 12, x: 0, y: 6)
        }
    }
}

// Secondary CTA — glass style
struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.18))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.4), lineWidth: 1))
        }
    }
}
```

---

## INPUT FIELDS

```swift
// Glass input field style
struct GlassInputField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .font(.system(size: 17, weight: .medium, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
    }
}
```

---

## BACKGROUNDS

```swift
// Full screen background — used on all main screens
struct AigosBackground: View {
    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [Color(hex: "#F5C97A"), Color(hex: "#C4793A")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Bokeh circles (decorative depth — like reference image)
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: -80, y: -120)

            Circle()
                .fill(Color(hex: "#E9A84C").opacity(0.15))
                .frame(width: 200, height: 200)
                .blur(radius: 40)
                .offset(x: 100, y: 200)
        }
    }
}
```

---

## SCREEN-SPECIFIC RULES

### Calculate (Tab 1 — default)
- Full gradient background with bokeh
- Result card: large glassmorphism card, centered
- ESTIMATED COST number: 52pt bold rounded, white, centered
- Breakdown rows: glass rows with amber left accent line
- "Calculate" button: full-width primary amber pill at bottom

### History (Tab 2)
- Darker gradient background (deeper amber)
- Trip rows: glass cards with subtle left border in amber
- Month headers: small caps, `.textTertiary`
- Cost: right-aligned, bold white

### Saved Routes (Tab 3)
- Same gradient base
- Route cards: glass cards with star icon in amber
- One-tap recalculate: secondary glass button

### Prices (Tab 4)
- Price rows: glass cards, one per fuel type
- Editable price: tappable, shows inline edit with amber underline
- Last updated date: small, tertiary, bottom of screen

### Settings (Tab 5)
- Grouped glass sections (like iOS Settings but warmer)
- Toggle switches: amber accent color
- Destructive actions (Clear History): white icon + white text + subtle red row-background tint, NOT red text (red is unreadable on amber)
- Settings/list row icons: white SF Symbol inside a small dark-amber rounded square (`SettingsIcon`) — the tile carries the colour, the glyph stays white

### Icon & contrast rules (global)
- **All SF Symbol icons are white** (0.85–0.9 inside glass). Never colour a glyph amber — amber-on-amber (and amber on the pale glass cards) is unreadable.
- **Amber is only for FILLS**, never glyphs: pill/button fills (white text on top), toggle/slider tint tracks, the amber progress bar, accent bars, circle/tile backgrounds behind a white icon.
- Section headers (`FieldLabel`): white 0.75, semibold, tracked, caps.
- Per-grade price bars keep their own colours (green/blue/purple/orange) — those are on glass, not amber glyphs.

### Tab Bar
- Deep amber/brown gradient background
- Background: dark brown #6B3A1F opacity 0.95 + blur (.ultraThinMaterial), top border white 0.15
- Selected tab: white icon + label
- Unselected tab: white opacity 0.35
- Unselected: white at 40% opacity
- No default iOS tab bar — custom styled

### Onboarding
- Full screen gradient per screen
- Mascot (jeepney): centered, large, glowing eyes in amber
- Title: large bold rounded, ALL CAPS
- Subtitle: medium weight, secondary opacity
- Progress dots: amber filled / white unfilled
- CTA: full-width amber pill

### Talk to aigos
- Mascot chat bubble: glass card, amber border glow
- Tap-to-answer buttons: glass pills, amber on selection
- Confidence label: small, tertiary, bottom

---

## ANIMATION PRINCIPLES

- **Spring animations** for cards appearing: `.spring(response: 0.4, dampingFraction: 0.7)`
- **Fade + slide up** for result reveal: `.transition(.move(edge: .bottom).combined(with: .opacity))`
- **No excessive animation** — one signature moment per screen
- **Haptic feedback** on Calculate tap: `UIImpactFeedbackGenerator(style: .medium)`
- Result number **counts up** from 0 to final value on appear (signature moment)

---

## DO / DON'T

| ✅ DO | ❌ DON'T |
|-------|---------|
| Warm amber gradients everywhere | Flat white or gray backgrounds |
| Glassmorphism cards with blur | Solid opaque cards |
| SF Pro Rounded for all text | Default SF Pro (too mechanical) |
| Large bold result numbers | Small or timid cost display |
| Soft bokeh depth circles | Hard geometric decorations |
| Amber glow on interactive elements | Blue (iOS default) accents |
| Capsule/pill shaped buttons | Square or slightly rounded buttons |
| White text on gradient backgrounds | Dark text on gradient |
| Breathable padding (24pt screen) | Cramped, dense layouts |
