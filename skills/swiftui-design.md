# Skill: SwiftUI Design — aigos

When building any SwiftUI view for aigos, always apply these patterns.
Read UI_GUIDELINES.md for the full token system. This skill is the quick reference.

---

## ALWAYS DO

### Background
Every screen gets `AigosBackground()` as the base layer — warm amber gradient + bokeh circles.
Never use `.background(Color.white)` or default system backgrounds.

```swift
ZStack {
    AigosBackground()
    // screen content
}
.ignoresSafeArea()
```

### Cards
All content containers use glassmorphism — never plain white or system grouped style.

```swift
VStack { ... }
.padding(20)
.background(Color.white.opacity(0.18))
.clipShape(RoundedRectangle(cornerRadius: 20))
.overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.35), lineWidth: 1))
.shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
```

### Typography
Always `.design: .rounded`. Never omit it.

```swift
.font(.system(size: 17, weight: .medium, design: .rounded))
```

### Colors
Never use `.blue`, `.gray`, `.black` or system colors directly.
Always reference the aigos color system from UI_GUIDELINES.md.
Primary accent is always `Color(hex: "#E9A84C")`.

### Buttons
Primary actions: amber fill, capsule shape, amber glow shadow.
Secondary actions: glass style, white stroke, capsule shape.
Never use default SwiftUI Button styling.

### Text on gradient backgrounds
Always white. `textPrimary = Color.white`, `textSecondary = Color.white.opacity(0.75)`.

---

## RESULT DISPLAY PATTERN

The estimated cost is the hero of the Calculate screen. Always display it like:

```swift
VStack(spacing: 4) {
    Text("ESTIMATED COST")
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundColor(.white.opacity(0.7))
        .kerning(1.5)

    Text("PHP 450.36")
        .font(.system(size: 52, weight: .bold, design: .rounded))
        .foregroundColor(.white)
}
```

---

## SCREEN TEMPLATE

```swift
struct ExampleView: View {
    var body: some View {
        ZStack {
            AigosBackground()

            ScrollView {
                VStack(spacing: 20) {
                    // Screen title
                    Text("SCREEN TITLE")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .kerning(1.2)

                    // Glass card
                    VStack(spacing: 16) {
                        // content
                    }
                    .padding(20)
                    .background(Color.white.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.35), lineWidth: 1))
                    .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)

                    // Primary CTA
                    Button("Calculate") { }
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(hex: "#E9A84C"))
                        .clipShape(Capsule())
                        .shadow(color: Color(hex: "#E9A84C").opacity(0.4), radius: 12, x: 0, y: 6)
                }
                .padding(.horizontal, 24)
            }
        }
        .ignoresSafeArea()
    }
}
```

---

## HEX COLOR EXTENSION (always include in project)

```swift
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255)
    }
}
```

---

## ANIMATION

Result reveal — always animate the cost card appearing:
```swift
.transition(.move(edge: .bottom).combined(with: .opacity))
.animation(.spring(response: 0.4, dampingFraction: 0.7), value: showResult)
```

Haptic on calculate tap:
```swift
UIImpactFeedbackGenerator(style: .medium).impactOccurred()
```
