//
//  Theme.swift
//  aigos
//
//  Brand colour. Primary accent is amber #E9A84C (Section 4).
//

import SwiftUI

extension Color {
    /// aigos brand amber — inspired by fuel and SLEX sunsets.
    static let aigosAmber = Color(hex: 0xE9A84C)

    /// Create a Color from a 24-bit RGB hex value, e.g. `Color(hex: 0xE9A84C)`.
    init(hex: UInt, alpha: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}
