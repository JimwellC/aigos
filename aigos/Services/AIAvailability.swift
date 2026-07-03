//
//  AIAvailability.swift
//  aigos
//
//  Apple Intelligence gate (Section 13). "Talk to aigos" understanding is powered
//  by the on-device Foundation Models system model *when available* — that requires
//  building against the Foundation Models SDK and running on an A17 Pro+ device
//  with Apple Intelligence enabled.
//
//  This SDK/toolchain does not ship Foundation Models, so the real path is compiled
//  in only behind `#if canImport(FoundationModels)`. Everywhere else — and on every
//  unsupported device — aigos falls back to its built-in offline query parser, so
//  the feature works 100% without AI (Section 22, note 4).
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

enum AIAvailability {
    enum Status: Equatable {
        case available
        case unavailable(String)
    }

    static var status: Status {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(let reason):
                return .unavailable(describe(reason))
            }
        }
        return .unavailable("Requires a newer iOS version.")
        #else
        return .unavailable("Apple Intelligence isn't in this build — using the built-in offline parser.")
        #endif
    }

    static var isAvailable: Bool {
        if case .available = status { return true }
        return false
    }

    /// Short label for the chat header badge.
    static var badgeText: String {
        isAvailable ? "Apple Intelligence" : "Offline understanding"
    }

    /// Longer explanation shown in AIGateView.
    static var explanation: String {
        switch status {
        case .available:
            return "Understanding runs entirely on-device with Apple Intelligence. Nothing leaves your iPhone."
        case .unavailable(let reason):
            return "\(reason) You can still ask aigos in plain English — it's understood on-device by the built-in parser, fully offline."
        }
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static func describe(_ reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            return "This iPhone doesn't support Apple Intelligence (needs iPhone 15 Pro or newer)."
        case .appleIntelligenceNotEnabled:
            return "Turn on Apple Intelligence in Settings to enable it."
        case .modelNotReady:
            return "The on-device model is still downloading."
        @unknown default:
            return "Apple Intelligence is currently unavailable."
        }
    }
    #endif
}
