//
//  AIAvailability.swift
//  aigos
//
//  "Talk to aigos" is a natural-language trip assistant whose understanding runs
//  entirely ON DEVICE. For v1.0 that's aigos's built-in offline parser
//  (`TripQueryParser`), which works on every iPhone with no account and no
//  internet.
//
//  A seam for an on-device system language model is kept behind
//  `#if canImport(FoundationModels)` for a future release (v1.1). It is compiled
//  in only when built against an SDK that ships the framework; it never changes
//  the user-facing wording, which stays provider-neutral ("on-device").
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

enum AIAvailability {
    enum Status: Equatable {
        case available      // an on-device system model is usable (v1.1 builds)
        case unavailable    // fall back to the built-in offline parser (v1.0)
    }

    /// Internal only — decides whether a future build can use the system model.
    /// Never surfaced as user-facing text.
    static var status: Status {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability { return .available }
        }
        return .unavailable
        #else
        return .unavailable
        #endif
    }

    static var isAvailable: Bool {
        if case .available = status { return true }
        return false
    }

    // MARK: - User-facing copy (provider-neutral; no device requirements)

    /// Short header badge.
    static var badgeText: String { "On-device" }

    /// One-line tagline for the assistant.
    static var tagline: String { "Natural-language trip assistant" }

    /// Longer explanation shown in the info sheet.
    static var explanation: String {
        "Ask aigos about any trip in plain English and it works out the cost for you. "
        + "Understanding happens entirely on your iPhone — no account, no internet, "
        + "nothing leaves your device."
    }
}
