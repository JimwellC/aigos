//
//  CrashReporter.swift
//  aigos
//
//  Lightweight on-device crash logging. This does NOT replace the OS / TestFlight
//  crash reporter (which is the source of truth for symbolicated traces) — it
//  captures a best-effort stack for BOTH Objective-C exceptions and fatal signals
//  so that:
//    • when the device is attached to Xcode, the stack prints to the console
//      immediately on crash, and
//    • the last crash is appended to a file in Documents that can be pulled via
//      Xcode's Devices window (Download Container) or a share sheet.
//
//  Signal handlers restore the default handler and re-raise, so the system crash
//  report is still produced and TestFlight/Organizer still symbolicate it.
//
//  Enable/disable is a single call from `aigosApp.init()`. Nothing here touches
//  the network or persists anything beyond a local text log.
//

import Foundation
import os

enum CrashReporter {

    private static let log = Logger(subsystem: "com.aigos.app", category: "crash")

    /// Path to the rolling crash-log file in the app's Documents directory.
    static var logFileURL: URL? {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("aigos-crash.log")
    }

    /// Install the exception + signal handlers. Idempotent; call once at launch.
    static func install() {
        installExceptionHandler()
        installSignalHandlers()
    }

    // MARK: - Objective-C exceptions (NSInvalidArgumentException, KVO, MapKit, …)

    private static func installExceptionHandler() {
        NSSetUncaughtExceptionHandler { exception in
            let symbols = exception.callStackSymbols.joined(separator: "\n")
            let report = """
            === aigos uncaught exception ===
            name:   \(exception.name.rawValue)
            reason: \(exception.reason ?? "nil")
            stack:
            \(symbols)
            ================================
            """
            CrashReporter.record(report)
        }
    }

    // MARK: - Fatal signals (SIGABRT from Swift traps, SIGSEGV, SIGILL, …)

    private static func installSignalHandlers() {
        // Swift runtime traps (force-unwrap nil, precondition, array OOB, Int(NaN))
        // surface as SIGILL/SIGTRAP/SIGABRT — the handler must be a C function with
        // no captured context.
        let signals: [Int32] = [SIGABRT, SIGILL, SIGSEGV, SIGFPE, SIGBUS, SIGTRAP, SIGPIPE]
        for sig in signals {
            signal(sig) { received in
                // Thread.callStackSymbols isn't strictly async-signal-safe, but is
                // reliable enough for a best-effort diagnostic log.
                let stack = Thread.callStackSymbols.joined(separator: "\n")
                CrashReporter.record("=== aigos fatal signal \(received) ===\n\(stack)\n=====================")
                // Restore the default handler and re-raise so the OS still writes
                // its own (symbolicable) crash report for TestFlight/Organizer.
                signal(received, SIG_DFL)
                raise(received)
            }
        }
    }

    // MARK: - Sink

    static func record(_ text: String) {
        log.fault("\(text, privacy: .public)")
        print(text)   // visible in Xcode console when the device is attached
        guard let url = logFileURL else { return }
        let stamped = "[crash @ launch-relative]\n\(text)\n\n"
        if let data = stamped.data(using: .utf8) {
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: url, options: .atomic)
            }
        }
    }
}
