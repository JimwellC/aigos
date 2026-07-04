//
//  NetworkMonitor.swift
//  aigos
//
//  Observes connectivity so the place search can show "🌐 Searching Apple Maps"
//  when online and "📵 Offline — major cities only" when offline. This only reads
//  the local network path status via NWPathMonitor — it sends nothing and needs
//  no entitlement. aigos stays fully usable offline (gazetteer); online just adds
//  Apple Maps place lookup on top.
//

import Foundation
import Network
import Observation

/// `@unchecked Sendable`: `isOnline` is only ever written on the main actor (via
/// the hop below) and read from SwiftUI bodies (also main), so it's effectively
/// main-isolated — the assertion just silences Swift 6's cross-actor check for
/// the shared singleton and the `@Sendable` path handler.
@Observable
final class NetworkMonitor: @unchecked Sendable {
    static let shared = NetworkMonitor()

    private(set) var isOnline = true
    private let monitor = NWPathMonitor()

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in self?.isOnline = online }
        }
        monitor.start(queue: DispatchQueue(label: "com.aigos.networkmonitor"))
    }
}
