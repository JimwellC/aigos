//
//  TripTracker.swift
//  aigos
//
//  GPS trip recording (v1.1 headline). A shared, battery-tuned CLLocationManager
//  that records the actual route while the user drives, accumulating distance and
//  live fuel/cost, and auto-detecting arrival. Runs in the background (blue
//  indicator). All GPS data is on-device only — nothing is transmitted.
//  `@unchecked Sendable`: state is only touched on the main thread (delegate
//  callbacks + the main-run-loop timer).
//

import Foundation
import CoreLocation
import UIKit
import UserNotifications

struct TripSummary {
    let actualDistanceKm: Double
    let actualDurationSeconds: Int
    let actualAvgSpeedKmh: Double
    let actualFuelL: Double
    let actualCostPHP: Double
    let accuracyPercent: Double
    let routeFlat: [Double]
    let startedAt: Date
    let endedAt: Date
}

@Observable
final class TripTracker: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
    static let shared = TripTracker()

    enum Status { case idle, requesting, tracking, paused, arrived, denied }

    private(set) var status: Status = .idle
    private(set) var distanceKm: Double = 0
    private(set) var currentSpeedKmh: Double = 0
    private(set) var elapsedSeconds: Int = 0
    private(set) var routeFlat: [Double] = []

    // Trip context (shown in the banner / used for the summary).
    private(set) var tripRecordId: UUID?
    private(set) var origin = ""
    private(set) var destination = ""
    private(set) var vehicleName = ""
    private(set) var estDistanceKm: Double = 0
    private(set) var estFuelL: Double = 0       // estimate context for the end-of-trip comparison
    private(set) var estCostPHP: Double = 0
    private(set) var ratedKmL: Double = 12
    private var efficiencyKmL: Double = 12
    private var pricePerLitre: Double = 0
    private var destCoord: CLLocationCoordinate2D?

    private let manager = CLLocationManager()
    private var lastLocation: CLLocation?
    private var startDate = Date()
    private var arrivalSince: Date?
    private var timer: Timer?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters   // battery-efficient
        manager.distanceFilter = 50                                  // 50 m between updates
        manager.activityType = .automotiveNavigation
        manager.pausesLocationUpdatesAutomatically = true            // auto-pause when parked
        // FOREGROUND-ONLY (v1.0): no background location mode, so when the app
        // backgrounds we pause and resume on return.
        NotificationCenter.default.addObserver(
            self, selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    /// Tracking (including the paused-in-background state) is "live".
    var isLive: Bool { status == .tracking || status == .arrived || status == .paused }
    /// Actively receiving updates (not paused).
    var isTracking: Bool { status == .tracking || status == .arrived }
    var fuelL: Double { TripMetrics.fuelLitres(distanceKm: distanceKm, efficiencyKmL: efficiencyKmL) }
    var costPHP: Double { fuelL * pricePerLitre }

    // MARK: - Control

    func start(tripRecordId: UUID, origin: String, destination: String, vehicleName: String,
               efficiencyKmL: Double, pricePerLitre: Double, estDistanceKm: Double,
               estFuelL: Double, estCostPHP: Double,
               destinationCoord: CLLocationCoordinate2D?) {
        reset()
        self.tripRecordId = tripRecordId
        self.origin = origin
        self.destination = destination
        self.vehicleName = vehicleName
        self.efficiencyKmL = max(efficiencyKmL, 0.1)
        self.ratedKmL = efficiencyKmL
        self.pricePerLitre = pricePerLitre
        self.estDistanceKm = estDistanceKm
        self.estFuelL = estFuelL
        self.estCostPHP = estCostPHP
        self.destCoord = destinationCoord
        self.startDate = Date()
        status = .requesting
        // Foreground-only: "While Using" is enough (usually already granted from the
        // map picker). Never request "Always" — that path led to the background-mode
        // crash. Begin once authorized.
        manager.requestWhenInUseAuthorization()
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: beginUpdates()
        case .denied, .restricted: status = .denied
        default: break   // wait for the authorization callback
        }
    }

    /// End tracking and return the computed actual-vs-estimated summary.
    func finish() -> TripSummary {
        let ended = Date()
        let summary = TripSummary(
            actualDistanceKm: distanceKm,
            actualDurationSeconds: elapsedSeconds,
            actualAvgSpeedKmh: TripMetrics.avgSpeedKmh(distanceKm: distanceKm, seconds: elapsedSeconds),
            actualFuelL: fuelL,
            actualCostPHP: costPHP,
            accuracyPercent: TripMetrics.accuracyPercent(estimated: estDistanceKm, actual: distanceKm),
            routeFlat: routeFlat,
            startedAt: startDate,
            endedAt: ended)
        stop()
        return summary
    }

    func cancel() { stop() }

    private func beginUpdates() {
        // FOREGROUND-ONLY: deliberately do NOT set allowsBackgroundLocationUpdates —
        // that requires the UIBackgroundModes "location" entitlement and throws
        // (crashes) without it once permission escalates to "Always". Foreground
        // location auto-pauses in the background anyway; we handle that explicitly.
        status = .tracking
        manager.startUpdatingLocation()
        startTimer()
    }

    private func stop() {
        manager.stopUpdatingLocation()
        timer?.invalidate(); timer = nil
        if status != .denied { status = .idle }
    }

    // MARK: - Foreground-only background handling

    @objc private func appDidEnterBackground() {
        guard status == .tracking || status == .arrived else { return }
        manager.stopUpdatingLocation()      // no background entitlement — pause cleanly
        currentSpeedKmh = 0
        status = .paused
        notifyPaused()
    }

    @objc private func appWillEnterForeground() {
        guard status == .paused else { return }
        status = .tracking
        manager.startUpdatingLocation()     // resume automatically
        lastLocation = nil                  // don't count the gap as a giant jump
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["trip-paused"])
    }

    /// A quiet nudge to reopen the app (provisional auth = no permission prompt).
    private func notifyPaused() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .provisional]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Trip tracking paused"
            content.body = "Reopen aigos to keep tracking your trip."
            center.add(UNNotificationRequest(identifier: "trip-paused", content: content, trigger: nil))
        }
    }

    private func reset() {
        distanceKm = 0; currentSpeedKmh = 0; elapsedSeconds = 0
        routeFlat = []; lastLocation = nil; arrivalSince = nil
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, self.isLive else { return }
            self.elapsedSeconds = Int(Date().timeIntervalSince(self.startDate))
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        switch m.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            if status == .requesting { beginUpdates() }
        case .denied, .restricted:
            status = .denied; stop()
        default:
            break
        }
    }

    func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        guard isTracking else { return }
        for loc in locs {
            if let last = lastLocation {
                let km = loc.distance(from: last) / 1000.0
                // Ignore implausible jumps (GPS noise) — 50 m filter, so >5 km is bogus.
                if km.isFinite, km < 5 { distanceKm += km }
            }
            lastLocation = loc
            routeFlat.append(loc.coordinate.latitude)
            routeFlat.append(loc.coordinate.longitude)
            currentSpeedKmh = max(0, loc.speed) * 3.6   // m/s → km/h (negative speed = invalid)
            checkArrival(loc)
        }
    }

    /// Auto-detect arrival: within 500 m of the destination for 2+ minutes.
    private func checkArrival(_ loc: CLLocation) {
        guard let dc = destCoord else { return }
        let dest = CLLocation(latitude: dc.latitude, longitude: dc.longitude)
        if loc.distance(from: dest) <= 500 {
            if arrivalSince == nil {
                arrivalSince = Date()
            } else if Date().timeIntervalSince(arrivalSince ?? Date()) >= 120 {
                status = .arrived
            }
        } else {
            arrivalSince = nil
        }
    }

    func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {}
}
