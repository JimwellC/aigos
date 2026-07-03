//
//  Formatting.swift
//  aigos
//
//  Currency + number formatting helpers.
//
//  IMPORTANT: currency renders as the "PHP" prefix (e.g. "PHP 261.43"), never
//  the ₱ glyph — the peso sign renders inconsistently across devices and PDF
//  exports (Section 22, note 6).
//

import Foundation

enum PHP {
    /// Formats a peso amount as "PHP 1,234.56".
    static func string(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let number = formatter.string(from: NSNumber(value: value))
            ?? String(format: "%.2f", value)
        return "PHP \(number)"
    }
}

extension Double {
    /// "PHP 261.43"
    var phpString: String { PHP.string(self) }

    /// One-decimal string, e.g. "82.4".
    var oneDecimal: String { String(format: "%.1f", self) }

    /// Percentage delta from a multiplier, e.g. 1.13 -> "+13%".
    var factorPercentString: String {
        let pct = Int(((self - 1.0) * 100).rounded())
        return pct >= 0 ? "+\(pct)%" : "\(pct)%"
    }
}
