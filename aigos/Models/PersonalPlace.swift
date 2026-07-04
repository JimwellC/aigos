//
//  PersonalPlace.swift
//  aigos
//
//  A user-named shortcut ("Home", "Office", "School") mapped to a real location.
//  Preferably a precise map-picked coordinate (lat/lon + reverse-geocoded address);
//  legacy places may still hold a city-level `gazetteerKey`. Lets natural queries
//  like "home to office" resolve to the user's own places before the nationwide
//  gazetteer. Local only, like everything else (no cloud).
//

import Foundation
import SwiftData

@Model
final class PersonalPlace {
    var id: UUID = UUID()
    var name: String = ""          // user label, e.g. "Home"
    var gazetteerKey: String = ""  // legacy city-level key; empty when map-picked
    var latitude: Double = 0       // precise map-picked coordinate (0/0 = unset)
    var longitude: Double = 0
    var displayName: String = ""   // reverse-geocoded address shown under "Mapped to"
    var createdAt: Date = Date()

    init(name: String, gazetteerKey: String = "") {
        self.id = UUID()
        self.name = name
        self.gazetteerKey = gazetteerKey
        self.createdAt = Date()
    }

    /// True once this shortcut points at a precise map-picked coordinate.
    var hasCoordinate: Bool { latitude != 0 || longitude != 0 }

    /// True once the user has mapped this shortcut to any real location.
    var isConfigured: Bool { hasCoordinate || !gazetteerKey.isEmpty }

    /// Precise point when map-picked; nil means callers fall back to `gazetteerKey`.
    var geoPoint: GeoPoint? { hasCoordinate ? GeoPoint(lat: latitude, lon: longitude) : nil }

    /// The human label shown under "Mapped to".
    var mappedLabel: String {
        if hasCoordinate {
            return displayName.isEmpty ? String(format: "%.4f, %.4f", latitude, longitude) : displayName
        }
        if !gazetteerKey.isEmpty { return gazetteerKey.capitalized }
        return "Not set"
    }

    /// Store a precise map-picked location (clears any legacy gazetteer mapping).
    func setCoordinate(lat: Double, lon: Double, address: String) {
        latitude = lat
        longitude = lon
        displayName = address
        gazetteerKey = ""
    }

    /// Forget the mapped location.
    func clearLocation() {
        latitude = 0
        longitude = 0
        displayName = ""
        gazetteerKey = ""
    }
}
