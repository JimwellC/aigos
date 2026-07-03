//
//  PersonalPlace.swift
//  aigos
//
//  A user-named shortcut ("Home", "Office", "School") mapped to a real location
//  from the gazetteer. Lets natural queries like "home to office" resolve to the
//  user's own places before falling back to the nationwide gazetteer. Local only,
//  like everything else (no cloud).
//

import Foundation
import SwiftData

@Model
final class PersonalPlace {
    var id: UUID = UUID()
    var name: String = ""          // user label, e.g. "Home"
    var gazetteerKey: String = ""  // a key in GazetteerRouteResolver.places; empty = not set yet
    var createdAt: Date = Date()

    init(name: String, gazetteerKey: String = "") {
        self.id = UUID()
        self.name = name
        self.gazetteerKey = gazetteerKey
        self.createdAt = Date()
    }

    /// True once the user has mapped this shortcut to a real location.
    var isConfigured: Bool { !gazetteerKey.isEmpty }
}
