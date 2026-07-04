//
//  KnowledgeBase.swift
//  aigos
//
//  Offline knowledge layer for Talk to aigos: fuel-economy education, vehicle
//  troubleshooting, Filipino car culture, seasonal advice, route facts, drive-vs-bus
//  cost, CO2, and best-time-to-travel. Backed by two bundled JSON data files
//  (RealWorldEfficiencyDatabase.json, RouteConditionsDatabase.json). Deterministic,
//  zero network. Recognises English + common Tagalog phrasings.
//

import Foundation

// MARK: - Bundled data

struct EfficiencyFactor: Decodable { let factor: Double; let label: String; var note: String? }
struct AgeBand: Decodable { let maxYears: Int; let factor: Double; let label: String; let note: String }

struct EfficiencyModifiers: Decodable {
    let age: [AgeBand]
    let maintenance: [String: EfficiencyFactor]
    let tires: [String: EfficiencyFactor]
    let driving: [String: EfficiencyFactor]
    let cargo: [String: EfficiencyFactor]
    let timeOfDay: [String: EfficiencyFactor]
    let weather: [String: EfficiencyFactor]
    let roadSurface: [String: EfficiencyFactor]
    let elevation: [String: EfficiencyFactor]

    /// Rated → real km/L factor for a vehicle of the given age (in years).
    func ageFactor(forYears years: Int) -> AgeBand {
        age.first { years <= $0.maxYears } ?? age.last!
    }
}

struct RouteInfo: Decodable, Equatable {
    let from: String
    let to: String
    let distanceKm: Double
    let via: String
    var tollMin: Int?
    var tollMax: Int?
    var timeHours: String?
    var elevationGainM: Int?
    var bestTime: String?
    var trafficPattern: String?
    var fuelNote: String?
    var gasStations: [String]?
}

struct TollFullRoute: Decodable, Equatable {
    let route: String
    let via: String
    let tollMin: Int
    let tollMax: Int
    let keys: [String]

    var tollText: String { tollMin == tollMax ? "PHP \(tollMin)" : "PHP \(tollMin)–\(tollMax)" }
}

struct TollData: Decodable {
    let classNote: String
    let disclaimer: String
    let fullRoutes: [TollFullRoute]
}

// MARK: - Knowledge base

enum KnowledgeBase {
    static let modifiers: EfficiencyModifiers? = loadModifiers()
    static let routes: [RouteInfo] = loadRoutes()
    static let tolls: TollData? = loadTolls()

    private static func loadTolls() -> TollData? {
        guard let url = Bundle.main.url(forResource: "TollDatabase", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(TollData.self, from: data)
    }

    private static func loadModifiers() -> EfficiencyModifiers? {
        guard let url = Bundle.main.url(forResource: "RealWorldEfficiencyDatabase", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(EfficiencyModifiers.self, from: data)
    }
    private static func loadRoutes() -> [RouteInfo] {
        struct File: Decodable { let routes: [RouteInfo] }
        guard let url = Bundle.main.url(forResource: "RouteConditionsDatabase", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data) else { return [] }
        return file.routes
    }

    /// Optional vehicle context so answers can personalise (name + savings/CO2 math).
    struct Vehicle { let name: String; let efficiencyKmL: Double; let fuelType: FuelType; let pricePerLitre: Double }

    // MARK: Entry point

    /// Answer an education / culture / route / cost question, or nil when the
    /// message isn't one of these (so Talk falls through to trips/vehicles).
    static func answer(for text: String, vehicle: Vehicle? = nil) -> String? {
        let q = text.lowercased()

        // Expressway / RFID / coding / emergency — checked first (toll shares the
        // "toll" keyword with route facts, so it must win).
        if isToll(q) { return tollAnswer(q) }
        if isRFIDLoad(q) { return rfidLoadAnswer }
        if isWhichRFID(q) { return whichRFIDAnswer }
        if isNumberCoding(q) { return numberCodingAnswer }
        if isEmergency(q) { return emergencyAnswer }

        // Route facts / drive-vs-bus / best-time all reference a route — resolve once.
        let route = matchedRoute(in: q)

        if isDriveVsBus(q) { return driveVsBusAnswer(q, route: route, vehicle: vehicle) }
        if isBestTime(q) { return bestTimeAnswer(route: route) }
        if isRouteFacts(q), let route { return routeFactsAnswer(route) }

        if isImproveEconomy(q) { return improveEconomyAnswer(vehicle) }
        if isWhenRefuel(q) { return refuelAnswer }
        if isFuelWastage(q) { return wastageAnswer }
        if isDieselVsGas(q) { return dieselVsGasAnswer }
        if isUsesMoreGas(q) { return usesMoreGasAnswer }
        if isNeedsPMS(q) { return needsPMSAnswer }
        if let premium = premiumForModelAnswer(q) { return premium }
        if isCO2(q) { return co2Answer(vehicle) }

        if isJeepney(q) { return jeepneyAnswer }
        if isTricycle(q) { return tricycleAnswer }
        if isFamilyCar(q) { return familyCarAnswer }
        if isTyphoon(q) { return typhoonAnswer }

        return nil
    }

    // MARK: - Intent detection

    private static func has(_ q: String, _ needles: [String]) -> Bool { needles.contains { q.contains($0) } }

    private static func isImproveEconomy(_ q: String) -> Bool {
        has(q, ["improve my fuel", "improve fuel economy", "improve mileage", "improve efficiency",
                "save on fuel", "save on gas", "save fuel", "better mileage", "better fuel economy",
                "makatipid sa gas", "makatipid sa gasolina", "paano makatipid", "mas matipid",
                "how to save gas", "tips to save"])
    }
    private static func isWhenRefuel(_ q: String) -> Bool {
        has(q, ["when should i refuel", "when to refuel", "when should i gas up", "when to gas up",
                "when do i refuel", "kailan mag gas", "kailan magpapa gas", "kailan dapat mag refuel"])
    }
    private static func isFuelWastage(_ q: String) -> Bool {
        has(q, ["fuel wastage", "waste fuel", "wasting fuel", "wasting gas", "waste gas",
                "causes fuel waste", "fuel waster", "sayang gasolina", "aksaya ng gas"])
    }
    private static func isDieselVsGas(_ q: String) -> Bool {
        has(q, ["diesel vs gas", "diesel vs gasoline", "gas vs diesel", "diesel or gas", "diesel or gasoline",
                "gasoline or diesel", "diesel o gasolina", "diesel ba o gasolina", "which is better diesel"])
    }
    private static func isUsesMoreGas(_ q: String) -> Bool {
        has(q, ["more gas lately", "uses more gas", "using more gas", "more fuel lately", "consuming more fuel",
                "fuel consumption increased", "eating more gas", "mas maraming gas", "dumami ang gas",
                "bakit mabilis maubos", "gas efficiency dropped", "efficiency dropped", "mileage dropped"])
    }
    private static func isNeedsPMS(_ q: String) -> Bool {
        has(q, ["needs pms", "need pms", "overdue pms", "needs service", "need service", "overdue service",
                "due for service", "overdue for maintenance", "kailangan mag pms", "kailangan ng pms", "needs maintenance"])
    }
    private static func isCO2(_ q: String) -> Bool {
        has(q, ["co2", "carbon", "emission", "carbon footprint", "greenhouse"])
    }
    private static func isJeepney(_ q: String) -> Bool {
        has(q, ["jeepney"]) && has(q, ["fuel", "km/l", "kml", "efficiency", "consumption", "gas", "mileage"])
    }
    private static func isTricycle(_ q: String) -> Bool {
        has(q, ["tricycle", "traysikel"]) && has(q, ["fuel", "gas", "cost", "km/l", "kml", "gastos", "efficiency"])
    }
    private static func isFamilyCar(_ q: String) -> Bool {
        has(q, ["family car", "car for family", "car for the family", "family vehicle", "best car for ph",
                "pampamilya", "sasakyan para sa pamilya"])
    }
    private static func isTyphoon(_ q: String) -> Bool {
        has(q, ["typhoon", "rainy season", "bagyo", "tag ulan", "tag-ulan", "storm season"])
    }
    private static func isDriveVsBus(_ q: String) -> Bool {
        has(q, ["bus"]) && has(q, ["cheaper", "vs", "or drive", "or take", "instead of", "than drive", "mas mura"])
    }
    private static func isBestTime(_ q: String) -> Bool {
        (has(q, ["best time", "what time is best", "anong oras", "anong best time", "when is the best time"])
         && has(q, ["drive", "travel", "go", "leave", "punta", "byahe"]))
    }
    private static func isToll(_ q: String) -> Bool { has(q, ["toll", "magkano ang toll", "toll fee", "toll rate"]) }
    private static func isRFIDLoad(_ q: String) -> Bool {
        has(q, ["rfid", "easytrip", "autosweep"])
            && has(q, ["load", "reload", "balance", "top up", "top-up", "magkano"])
    }
    private static func isWhichRFID(_ q: String) -> Bool {
        has(q, ["rfid", "easytrip", "autosweep"])
            && has(q, ["which", "what rfid", "need", "get", "interoperable", "one rfid", "anong rfid", "difference"])
    }
    private static func isNumberCoding(_ q: String) -> Bool {
        has(q, ["number coding", "coding scheme", "uvvrp", "color coding", "window hours",
                "plate ending", "coding day", "coding today", "anong coding", "am i coded"])
    }
    private static func isEmergency(_ q: String) -> Bool {
        has(q, ["break down", "broke down", "breakdown", "stranded", "need a tow", "towing", "get towed",
                "emergency number", "emergency contact", "emergency hotline", "flat tire on",
                "accident on the expressway", "nasiraan", "aksidente sa"])
    }
    private static func isRouteFacts(_ q: String) -> Bool {
        has(q, ["toll", "route", "gas station", "how far", "distance", "how long", "elevation", "gaano kalayo", "gaano katagal"])
    }

    // MARK: - Route helpers

    private static func matchedRoute(in q: String) -> RouteInfo? {
        // Prefer a route whose destination is named; break ties by also matching origin.
        let byDest = routes.filter { q.contains($0.to.lowercased()) }
        if byDest.count > 1, let both = byDest.first(where: { q.contains($0.from.lowercased()) }) { return both }
        return byDest.first ?? routes.first { q.contains($0.from.lowercased()) && q.contains($0.to.lowercased()) }
    }

    private static func toll(_ r: RouteInfo) -> String {
        guard let lo = r.tollMin else { return "toll varies" }
        return lo == (r.tollMax ?? lo) ? "PHP \(lo)" : "PHP \(lo)–\(r.tollMax ?? lo)"
    }

    private static func routeFactsAnswer(_ r: RouteInfo) -> String {
        var lines = ["\(r.from) → \(r.to) — the essentials:",
                     "• Distance: ≈\(Int(r.distanceKm)) km via \(r.via)",
                     "• Toll: \(toll(r))"]
        if let t = r.timeHours { lines.append("• Time: \(t) hours (traffic-dependent)") }
        if let e = r.elevationGainM { lines.append("• Elevation gain: ~\(e) m") }
        if let b = r.bestTime { lines.append("• Best time to leave: \(b)") }
        if let p = r.trafficPattern { lines.append("• Traffic: \(p)") }
        if let f = r.fuelNote { lines.append("• Fuel: \(f)") }
        if let g = r.gasStations, !g.isEmpty { lines.append("• Gas stops: \(g.joined(separator: ", "))") }
        lines.append("\nWant the fuel cost? Ask “How much to drive \(r.from) to \(r.to)?”")
        return lines.joined(separator: "\n")
    }

    // MARK: - Cost, timing, CO2 (context-aware)

    private static func driveVsBusAnswer(_ q: String, route: RouteInfo?, vehicle: Vehicle?) -> String {
        guard let r = route else {
            return "Rough rule for PH road trips: solo, the bus usually wins; with 2 passengers it's about even; with 3–4 sharing, driving your own car is cheaper — plus you keep your own schedule. Tell me the route (e.g. “drive or bus to Baguio?”) and your vehicle and I'll compare the pesos."
        }
        let tollAvg = Double(((r.tollMin ?? 0) + (r.tollMax ?? r.tollMin ?? 0)) / 2)
        var driveLine = "fuel + toll"
        if let v = vehicle {
            let fuel = r.distanceKm / v.efficiencyKmL * v.pricePerLitre
            let oneWay = fuel + tollAvg
            driveLine = "≈\(oneWay.phpString) one-way (fuel \(fuel.phpString) + toll ≈PHP \(Int(tollAvg))), so ≈\((oneWay * 2).phpString) round-trip"
        }
        // Rough intercity bus fare ≈ PHP 3.2 / km one-way.
        let busOneWay = r.distanceKm * 3.2
        return """
        \(r.from) → \(r.to) (≈\(Int(r.distanceKm)) km):

        DRIVE\(vehicle.map { " (\($0.name))" } ?? ""): \(driveLine).
        BUS: ≈PHP \(Int(busOneWay))–\(Int(busOneWay * 1.25)) one-way per person.

        Verdict: solo → the bus is cheaper. With 3–4 passengers sharing, driving is the clear win (and your own schedule). \(vehicle == nil ? "Set a default vehicle and I'll put exact pesos on the driving side." : "")
        """
    }

    private static func bestTimeAnswer(route: RouteInfo?) -> String {
        var s = """
        Best times to travel around Metro Manila / to the provinces:

        Manila ↔ provinces:
        • Sat 4–8 AM — BEST for heading out
        • Fri 3–8 PM — WORST (avoid)
        • Sun 4–9 PM — WORST returning
        • Mon–Thu — manageable anytime

        Within Metro Manila:
        • 6–8 AM — heavy inbound
        • 5–9 PM — heavy outbound
        • 10 AM–3 PM — moderate
        • After 10 PM — light
        """
        if let r = route, let b = r.bestTime {
            s += "\n\nFor \(r.from) → \(r.to): leave around \(b)\(r.trafficPattern.map { " (\($0))" } ?? "")."
        }
        return s
    }

    private static func co2Answer(_ vehicle: Vehicle?) -> String {
        let base = """
        Burning 1 litre of fuel releases ≈2.31 kg of CO₂. So for a trip: litres used × 2.31 = kg CO₂.
        """
        var example = ""
        if let v = vehicle {
            let litres100 = 100.0 / v.efficiencyKmL
            let co2 = litres100 * 2.31
            example = "\n\nFor your \(v.name) (~\(VehicleDatabase.fmt(v.efficiencyKmL)) km/L), every 100 km ≈ \(VehicleDatabase.fmt(litres100)) L → ≈\(VehicleDatabase.fmt(co2)) kg CO₂."
        }
        return base + example + """


        Ways to cut it:
        • Combine trips into one
        • Carpool with 3–4 people
        • Keep your vehicle well-maintained
        • Consider hybrid/electric next time
        """
    }

    private static func improveEconomyAnswer(_ vehicle: Vehicle?) -> String {
        var s = """
        Great question! Top fuel-saving tips for PH roads:

        1. Hold a steady 80–90 km/h on the highway (the efficiency sweet spot)
        2. Keep tires at the recommended PSI (check monthly)
        3. Get PMS every 5,000–10,000 km
        4. Remove roof racks when not in use
        5. Turn off the AC when you don't need it (saves 10–15%)
        6. Avoid long idling
        7. Plan routes to dodge rush hour
        8. Use cruise control on highways
        9. Accelerate smoothly, brake gently
        10. Keep the car clean and well-maintained
        """
        if let v = vehicle {
            // Eco-driving ≈ +10%; rough monthly saving on ~1,000 km of driving.
            let kmMonth = 1000.0
            let litresNow = kmMonth / v.efficiencyKmL
            let litresBetter = kmMonth / (v.efficiencyKmL * 1.10)
            let save = (litresNow - litresBetter) * v.pricePerLitre
            s += "\n\nFor your \(v.name), these habits could save roughly \(save.phpString) a month (on ~1,000 km)."
        }
        return s
    }

    private static func premiumForModelAnswer(_ q: String) -> String? {
        guard q.contains("premium 95") || q.contains("premium95") || q.contains("premium gas") else { return nil }
        guard let entry = VehicleDatabase.find(q) else { return nil }
        if entry.fuelType == .unleaded91 {
            return "The \(entry.makeModel) is designed for Unleaded 91 — Premium 95 gives it NO benefit and just costs about PHP 1 more per litre (~PHP 40 wasted per tank). Only step up to Premium 95 if your manual requires it, you have a turbo/high-compression engine, or you hear knocking on 91. For your \(entry.makeModel): stick with Unleaded 91."
        }
        return "The \(entry.makeModel) runs on \(entry.fuelType.label) — use what the manufacturer recommends. Premium grades only help if the engine specifically calls for them."
    }

    // MARK: - Canned knowledge

    private static let refuelAnswer = """
    Refuel when your tank drops below 1/4 full. Why:
    • The fuel pump stays cooler and lasts longer
    • Less water condensation in the tank
    • No emergency low-fuel situations
    • You can wait for your preferred station's price

    aigos also flags a LOW FUEL warning when a trip needs more than your current tank can provide.
    """

    private static let wastageAnswer = """
    Top fuel wasters in Philippine driving:
    1. Traffic idling (EDSA rush hour burns 1–2 L/hour just sitting)
    2. Heavy AC use in hot weather
    3. Aggressive acceleration from a stop
    4. Speeding above 100 km/h on the highway
    5. Overloading with passengers/cargo
    6. Under-inflated tires
    7. A dirty air filter
    8. Roof carriers that add drag
    """

    private static let dieselVsGasAnswer = """
    For Philippine driving:

    Choose DIESEL if:
    • You drive 20,000+ km/year
    • Long highway trips are common
    • You haul heavy loads
    • You want 20–30% better economy
    • e.g. Innova, Fortuner, Hilux, Montero, Everest

    Choose GASOLINE if:
    • Mostly city driving under 15,000 km/year
    • You want a lower upfront cost
    • You prefer quieter, smoother operation
    • Simpler maintenance
    • e.g. Vios, City, Wigo, Mirage

    Diesel usually pumps a few pesos cheaper per litre AND goes further — but costs more to buy and service.
    """

    private static let usesMoreGasAnswer = """
    Common causes of a sudden fuel-efficiency drop:
    1. Dirty air filter (easy, ~PHP 300–800)
    2. Overdue spark plugs (~PHP 200–800 each)
    3. Faulty oxygen sensor (~PHP 2,000–8,000)
    4. Low tire pressure (free to fix!)
    5. Bad fuel injectors
    6. Clogged fuel filter
    7. Dragging brakes
    8. Wrong engine-oil viscosity
    9. AC compressor issues
    10. Ethanol content variation

    Start cheap: PMS check, inflate the tires, and try a different station.
    """

    // MARK: - Toll / RFID / coding / emergency

    private static func tollAnswer(_ q: String) -> String? {
        guard let t = tolls else { return nil }
        if let r = t.fullRoutes.first(where: { $0.keys.contains { q.contains($0) } }) {
            return "\(r.route) toll (\(r.via)): \(r.tollText) for Class 1.\n\n\(t.classNote)\n\n\(t.disclaimer)"
        }
        let common = t.fullRoutes.prefix(6).map { "• \($0.route): \($0.tollText)" }.joined(separator: "\n")
        return "Common Class 1 expressway tolls:\n\(common)\n\nTell me your destination for an exact figure.\n\n\(t.classNote)\n\n\(t.disclaimer)"
    }

    private static let rfidLoadAnswer = """
    RFID reload options:
    • GCash: Pay Bills → Easytrip or Autosweep
    • Maya: Bills → RFID
    • BDO / BPI / Metrobank online banking
    • 7-Eleven (over the counter)
    • Expressway reload centers at the toll plazas

    Minimum reload PHP 200; load PHP 500+ before a long trip.
    Check balance — Easytrip: easytrip.ph · Autosweep: autosweep.com.ph
    """

    private static let whichRFIDAnswer = """
    Since December 2024, one RFID works on ALL expressways (they're interoperable) — get whichever is easier to find:

    • Easytrip (MPTC): NLEX plazas, SM, Robinsons, hardware stores
    • Autosweep (SMC): SLEX/Skyway, SM, Robinsons, Shell stations

    Cost: about PHP 150–200 (one-time sticker + initial load).
    """

    private static let numberCodingAnswer = """
    MMDA Number Coding (UVVRP) — by last plate digit:
    • Mon: 1 & 2
    • Tue: 3 & 4
    • Wed: 5 & 6
    • Thu: 7 & 8
    • Fri: 9 & 0

    Hours: 7:00 AM – 8:00 PM, on EDSA and major Manila roads.
    Exempt: expressways (NLEX, SLEX, Skyway) and provincial roads.

    Coding matters for fuel too — detours add km, which add fuel. Factor it into your budget!
    """

    private static let emergencyAnswer = """
    If you break down on the expressway:
    1. Turn on your hazard lights immediately
    2. Pull onto the shoulder / emergency lane
    3. Place an early-warning device ~30 m behind
    4. Call the expressway hotline
    5. Call MMDA: 136
    6. Stay INSIDE the vehicle or behind the barrier — never between your car and traffic

    Hotlines:
    • NLEX / SCTEX / TPLEX: 1-800-8-NLEX (6539)
    • SLEX / Skyway: (02) 8-843-5359
    • CALAX / CAVITEX: 1-800-888-2539
    • All expressways: 136

    Towing to the nearest exit is FREE on most expressways.
    """

    private static let needsPMSAnswer = """
    An overdue PMS typically cuts fuel efficiency by ~15%. Servicing your car soon (oil, filters, spark plugs) could save you roughly PHP 800–1,200 a month in fuel — and prevent bigger repairs later. In aigos, set the vehicle's maintenance to "Overdue PMS" so your estimates reflect it.
    """

    private static let jeepneyAnswer = """
    Jeepney fuel efficiency (diesel):
    • Traditional jeepney: 5–7 km/L
    • Modern Euro-4 jeepney: 8–10 km/L
    • Modernized PUV: 10–12 km/L
    • Electric jeepney: ~4–5 kWh/km (no diesel)
    """

    private static let tricycleAnswer = """
    Typical tricycle (150cc motor):
    • Efficiency: 25–35 km/L
    • Daily use (~200 km): 6–8 litres
    • Roughly 60% cheaper on fuel than a 4-wheel vehicle for the same route
    """

    private static let familyCarAnswer = """
    Top 5 family vehicles for PH:
    1. Toyota Avanza — ~14.2 km/L, 7 seats
    2. Mitsubishi Xpander — ~13.5 km/L, best comfort
    3. Honda BR-V — ~14.5 km/L, sportier drive
    4. Toyota Innova (diesel) — ~11.5 km/L, best for long trips
    5. Suzuki Ertiga — ~16.5 km/L, most fuel-efficient

    Over 5 years, the diesel Innova costs a bit more in fuel than an Avanza — usually offset by comfort and long-trip ability.
    """

    private static let typhoonAnswer = """
    June–October is typhoon season. Keep in mind:
    • Fuel use climbs 15–20% in heavy rain
    • Traffic worsens with flooding; evacuation may be needed
    • Keep your tank at least half full
    • Check the weather before long trips

    Best months for road trips: December–May (dry season, lighter provincial traffic).
    """
}
