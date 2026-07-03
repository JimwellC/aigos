//
//  RouteResolver.swift
//  aigos
//
//  Offline distance estimation (v1.0).
//
//  aigos estimates trip distance entirely offline from a bundled gazetteer of
//  Philippine provinces and cities — straight-line (haversine) distance scaled by
//  a road-winding factor. Results are always labelled "estimated" in the UI, and
//  manual distance entry is front-and-centre so the user can type an exact figure
//  (e.g. from their odometer or a maps app) any time.
//
//  `RouteResolver` is the seam: v1.1 can drop in precise turn-by-turn routing
//  (OSRM + a bundled OpenStreetMap PH extract) behind the same protocol without
//  touching any view. That's deferred because embedding a routing engine + map
//  data is a large, self-contained piece of work; the gazetteer estimate plus
//  manual entry covers the v1.0 use case honestly today.
//

import Foundation

struct GeoPoint: Sendable, Equatable {
    let lat: Double
    let lon: Double
}

struct RouteResult: Sendable, Equatable {
    let distanceKm: Double
    /// True when the distance is an approximation (gazetteer/haversine) rather
    /// than a precise road route. Drives the "estimated" label in the UI.
    let isEstimated: Bool
}

protocol RouteResolver {
    /// Resolve a driving distance between two free-text place names, or nil if
    /// either place is unknown (caller then falls back to manual entry).
    func route(from origin: String, to destination: String) -> RouteResult?
}

/// Offline distance estimator backed by a small gazetteer of PH population
/// centres. Straight-line (haversine) distance is scaled by a winding factor to
/// approximate real road distance.
struct GazetteerRouteResolver: RouteResolver {

    /// Empirical multiplier: PH road distance runs ~30% longer than straight line.
    private let windingFactor = 1.30

    /// Nationwide gazetteer — every Philippine province (keyed by name → its
    /// capital) plus major/independent cities and common destinations, so most
    /// origin/destination inputs and NL queries resolve. Coordinates are
    /// approximate (distance is an estimate anyway). Built with
    /// `uniquingKeysWith` so a duplicate key can never crash the app at launch.
    static let places: [String: GeoPoint] = Dictionary(
        [
            // — NCR / Metro Manila —
            ("manila", GeoPoint(lat: 14.5995, lon: 120.9842)),
            ("metro manila", GeoPoint(lat: 14.5995, lon: 120.9842)),
            ("quezon city", GeoPoint(lat: 14.6760, lon: 121.0437)),
            ("qc", GeoPoint(lat: 14.6760, lon: 121.0437)),
            ("makati", GeoPoint(lat: 14.5547, lon: 121.0244)),
            ("bgc", GeoPoint(lat: 14.5507, lon: 121.0494)),
            ("pasig", GeoPoint(lat: 14.5764, lon: 121.0851)),
            ("taguig", GeoPoint(lat: 14.5176, lon: 121.0509)),
            ("caloocan", GeoPoint(lat: 14.6577, lon: 120.9727)),
            ("mandaluyong", GeoPoint(lat: 14.5794, lon: 121.0359)),
            ("marikina", GeoPoint(lat: 14.6507, lon: 121.1029)),
            ("muntinlupa", GeoPoint(lat: 14.4081, lon: 121.0415)),
            ("paranaque", GeoPoint(lat: 14.4793, lon: 121.0198)),
            ("las pinas", GeoPoint(lat: 14.4453, lon: 120.9833)),
            ("pasay", GeoPoint(lat: 14.5378, lon: 121.0014)),
            ("valenzuela", GeoPoint(lat: 14.7011, lon: 120.9830)),
            ("malabon", GeoPoint(lat: 14.6570, lon: 120.9569)),
            ("navotas", GeoPoint(lat: 14.6664, lon: 120.9422)),
            ("san juan", GeoPoint(lat: 14.6019, lon: 121.0355)),
            ("pateros", GeoPoint(lat: 14.5455, lon: 121.0685)),

            // — Cordillera (CAR) —
            ("baguio", GeoPoint(lat: 16.4023, lon: 120.5960)),
            ("benguet", GeoPoint(lat: 16.4550, lon: 120.5870)),
            ("la trinidad", GeoPoint(lat: 16.4550, lon: 120.5870)),
            ("abra", GeoPoint(lat: 17.5960, lon: 120.6180)),
            ("bangued", GeoPoint(lat: 17.5960, lon: 120.6180)),
            ("apayao", GeoPoint(lat: 18.0180, lon: 121.1830)),
            ("ifugao", GeoPoint(lat: 16.8330, lon: 121.1000)),
            ("banaue", GeoPoint(lat: 16.9100, lon: 121.0580)),
            ("kalinga", GeoPoint(lat: 17.4090, lon: 121.4440)),
            ("tabuk", GeoPoint(lat: 17.4090, lon: 121.4440)),
            ("mountain province", GeoPoint(lat: 17.0890, lon: 120.9760)),
            ("bontoc", GeoPoint(lat: 17.0890, lon: 120.9760)),
            ("sagada", GeoPoint(lat: 17.0840, lon: 120.9010)),

            // — Ilocos Region (I) —
            ("ilocos norte", GeoPoint(lat: 18.1978, lon: 120.5936)),
            ("laoag", GeoPoint(lat: 18.1978, lon: 120.5936)),
            ("ilocos sur", GeoPoint(lat: 17.5747, lon: 120.3869)),
            ("vigan", GeoPoint(lat: 17.5747, lon: 120.3869)),
            ("ilocos", GeoPoint(lat: 17.5747, lon: 120.3869)),
            ("la union", GeoPoint(lat: 16.6159, lon: 120.3166)),
            ("san fernando la union", GeoPoint(lat: 16.6159, lon: 120.3166)),
            ("pangasinan", GeoPoint(lat: 16.0217, lon: 120.2320)),
            ("lingayen", GeoPoint(lat: 16.0217, lon: 120.2320)),
            ("dagupan", GeoPoint(lat: 16.0431, lon: 120.3339)),
            ("alaminos", GeoPoint(lat: 16.1560, lon: 119.9810)),
            ("urdaneta", GeoPoint(lat: 15.9760, lon: 120.5710)),
            ("san carlos", GeoPoint(lat: 15.9280, lon: 120.3490)),
            ("bolinao", GeoPoint(lat: 16.3860, lon: 119.8900)),

            // — Cagayan Valley (II) —
            ("cagayan", GeoPoint(lat: 17.6132, lon: 121.7270)),
            ("tuguegarao", GeoPoint(lat: 17.6132, lon: 121.7270)),
            ("isabela", GeoPoint(lat: 17.1490, lon: 121.8890)),
            ("ilagan", GeoPoint(lat: 17.1490, lon: 121.8890)),
            ("santiago", GeoPoint(lat: 16.6880, lon: 121.5480)),
            ("cauayan", GeoPoint(lat: 16.9350, lon: 121.7710)),
            ("nueva vizcaya", GeoPoint(lat: 16.4820, lon: 121.1490)),
            ("bayombong", GeoPoint(lat: 16.4820, lon: 121.1490)),
            ("quirino", GeoPoint(lat: 16.5710, lon: 121.5250)),
            ("batanes", GeoPoint(lat: 20.4490, lon: 121.9700)),
            ("basco", GeoPoint(lat: 20.4490, lon: 121.9700)),

            // — Central Luzon (III) —
            ("pampanga", GeoPoint(lat: 15.0286, lon: 120.6898)),
            ("san fernando", GeoPoint(lat: 15.0286, lon: 120.6898)),
            ("angeles", GeoPoint(lat: 15.1450, lon: 120.5887)),
            ("mabalacat", GeoPoint(lat: 15.2210, lon: 120.5750)),
            ("clark", GeoPoint(lat: 15.1855, lon: 120.5601)),
            ("bulacan", GeoPoint(lat: 14.7969, lon: 120.8797)),
            ("malolos", GeoPoint(lat: 14.8433, lon: 120.8113)),
            ("meycauayan", GeoPoint(lat: 14.7360, lon: 120.9600)),
            ("san jose del monte", GeoPoint(lat: 14.8139, lon: 121.0453)),
            ("baliuag", GeoPoint(lat: 14.9550, lon: 120.8960)),
            ("nueva ecija", GeoPoint(lat: 15.5410, lon: 121.0790)),
            ("palayan", GeoPoint(lat: 15.5410, lon: 121.0790)),
            ("cabanatuan", GeoPoint(lat: 15.4869, lon: 120.9675)),
            ("gapan", GeoPoint(lat: 15.3080, lon: 120.9470)),
            ("tarlac", GeoPoint(lat: 15.4755, lon: 120.5960)),
            ("zambales", GeoPoint(lat: 15.3280, lon: 119.9780)),
            ("iba", GeoPoint(lat: 15.3280, lon: 119.9780)),
            ("olongapo", GeoPoint(lat: 14.8292, lon: 120.2828)),
            ("subic", GeoPoint(lat: 14.8797, lon: 120.2350)),
            ("bataan", GeoPoint(lat: 14.6760, lon: 120.5360)),
            ("balanga", GeoPoint(lat: 14.6760, lon: 120.5360)),
            ("aurora", GeoPoint(lat: 15.7580, lon: 121.5610)),
            ("baler", GeoPoint(lat: 15.7580, lon: 121.5610)),

            // — CALABARZON (IV-A) —
            ("cavite", GeoPoint(lat: 14.4791, lon: 120.8970)),
            ("cavite city", GeoPoint(lat: 14.4791, lon: 120.8970)),
            ("trece martires", GeoPoint(lat: 14.2820, lon: 120.8680)),
            ("bacoor", GeoPoint(lat: 14.4590, lon: 120.9490)),
            ("dasmarinas", GeoPoint(lat: 14.3290, lon: 120.9370)),
            ("imus", GeoPoint(lat: 14.4290, lon: 120.9370)),
            ("general trias", GeoPoint(lat: 14.3860, lon: 120.8810)),
            ("kawit", GeoPoint(lat: 14.4440, lon: 120.9040)),
            ("tagaytay", GeoPoint(lat: 14.1153, lon: 120.9621)),
            ("laguna", GeoPoint(lat: 14.2820, lon: 121.4160)),
            ("santa cruz", GeoPoint(lat: 14.2820, lon: 121.4160)),
            ("calamba", GeoPoint(lat: 14.2117, lon: 121.1653)),
            ("santa rosa", GeoPoint(lat: 14.3122, lon: 121.1114)),
            ("san pablo", GeoPoint(lat: 14.0680, lon: 121.3250)),
            ("binan", GeoPoint(lat: 14.3330, lon: 121.0810)),
            ("cabuyao", GeoPoint(lat: 14.2470, lon: 121.1360)),
            ("los banos", GeoPoint(lat: 14.1700, lon: 121.2410)),
            ("batangas", GeoPoint(lat: 13.7565, lon: 121.0583)),
            ("batangas city", GeoPoint(lat: 13.7565, lon: 121.0583)),
            ("lipa", GeoPoint(lat: 13.9411, lon: 121.1622)),
            ("tanauan", GeoPoint(lat: 14.0860, lon: 121.1490)),
            ("nasugbu", GeoPoint(lat: 14.0720, lon: 120.6320)),
            ("lucena", GeoPoint(lat: 13.9373, lon: 121.6170)),
            ("rizal", GeoPoint(lat: 14.5932, lon: 121.1760)),
            ("antipolo", GeoPoint(lat: 14.5932, lon: 121.1760)),

            // — MIMAROPA (IV-B) —
            ("occidental mindoro", GeoPoint(lat: 13.2240, lon: 120.5960)),
            ("mamburao", GeoPoint(lat: 13.2240, lon: 120.5960)),
            ("oriental mindoro", GeoPoint(lat: 13.4110, lon: 121.1800)),
            ("calapan", GeoPoint(lat: 13.4110, lon: 121.1800)),
            ("mindoro", GeoPoint(lat: 13.4110, lon: 121.1800)),
            ("marinduque", GeoPoint(lat: 13.4470, lon: 121.8400)),
            ("boac", GeoPoint(lat: 13.4470, lon: 121.8400)),
            ("romblon", GeoPoint(lat: 12.5750, lon: 122.2710)),
            ("palawan", GeoPoint(lat: 9.7390, lon: 118.7350)),
            ("puerto princesa", GeoPoint(lat: 9.7390, lon: 118.7350)),
            ("coron", GeoPoint(lat: 12.0050, lon: 120.2040)),
            ("el nido", GeoPoint(lat: 11.1960, lon: 119.3910)),

            // — Bicol (V) —
            ("camarines norte", GeoPoint(lat: 14.1120, lon: 122.9550)),
            ("daet", GeoPoint(lat: 14.1120, lon: 122.9550)),
            ("camarines sur", GeoPoint(lat: 13.6218, lon: 123.1948)),
            ("naga", GeoPoint(lat: 13.6218, lon: 123.1948)),
            ("pili", GeoPoint(lat: 13.5850, lon: 123.2740)),
            ("bicol", GeoPoint(lat: 13.6218, lon: 123.1948)),
            ("albay", GeoPoint(lat: 13.1391, lon: 123.7438)),
            ("legazpi", GeoPoint(lat: 13.1391, lon: 123.7438)),
            ("legaspi", GeoPoint(lat: 13.1391, lon: 123.7438)),
            ("sorsogon", GeoPoint(lat: 12.9740, lon: 124.0060)),
            ("catanduanes", GeoPoint(lat: 13.5850, lon: 124.2380)),
            ("virac", GeoPoint(lat: 13.5850, lon: 124.2380)),
            ("masbate", GeoPoint(lat: 12.3660, lon: 123.6210)),
            ("iriga", GeoPoint(lat: 13.4270, lon: 123.4110)),
            ("tabaco", GeoPoint(lat: 13.3590, lon: 123.7330)),
            ("ligao", GeoPoint(lat: 13.2320, lon: 123.5170)),

            // — Western Visayas (VI) —
            ("aklan", GeoPoint(lat: 11.7080, lon: 122.3660)),
            ("kalibo", GeoPoint(lat: 11.7080, lon: 122.3660)),
            ("boracay", GeoPoint(lat: 11.9670, lon: 121.9240)),
            ("antique", GeoPoint(lat: 10.7440, lon: 121.9390)),
            ("san jose de buenavista", GeoPoint(lat: 10.7440, lon: 121.9390)),
            ("capiz", GeoPoint(lat: 11.5850, lon: 122.7510)),
            ("roxas", GeoPoint(lat: 11.5850, lon: 122.7510)),
            ("guimaras", GeoPoint(lat: 10.5950, lon: 122.5940)),
            ("jordan", GeoPoint(lat: 10.5950, lon: 122.5940)),
            ("iloilo", GeoPoint(lat: 10.7202, lon: 122.5621)),
            ("negros occidental", GeoPoint(lat: 10.6407, lon: 122.9689)),
            ("bacolod", GeoPoint(lat: 10.6407, lon: 122.9689)),
            ("bago", GeoPoint(lat: 10.5380, lon: 122.8360)),
            ("silay", GeoPoint(lat: 10.7980, lon: 122.9750)),

            // — Central Visayas (VII) —
            ("bohol", GeoPoint(lat: 9.6470, lon: 123.8540)),
            ("tagbilaran", GeoPoint(lat: 9.6470, lon: 123.8540)),
            ("panglao", GeoPoint(lat: 9.5790, lon: 123.7480)),
            ("cebu", GeoPoint(lat: 10.3157, lon: 123.8854)),
            ("cebu city", GeoPoint(lat: 10.3157, lon: 123.8854)),
            ("mandaue", GeoPoint(lat: 10.3230, lon: 123.9220)),
            ("lapu-lapu", GeoPoint(lat: 10.3100, lon: 123.9490)),
            ("mactan", GeoPoint(lat: 10.3100, lon: 123.9490)),
            ("talisay", GeoPoint(lat: 10.2450, lon: 123.8490)),
            ("negros oriental", GeoPoint(lat: 9.3070, lon: 123.3080)),
            ("dumaguete", GeoPoint(lat: 9.3070, lon: 123.3080)),
            ("siquijor", GeoPoint(lat: 9.2140, lon: 123.5150)),
            ("toledo", GeoPoint(lat: 10.3770, lon: 123.6390)),

            // — Eastern Visayas (VIII) —
            ("leyte", GeoPoint(lat: 11.2440, lon: 125.0040)),
            ("tacloban", GeoPoint(lat: 11.2440, lon: 125.0040)),
            ("southern leyte", GeoPoint(lat: 10.1330, lon: 124.8440)),
            ("maasin", GeoPoint(lat: 10.1330, lon: 124.8440)),
            ("biliran", GeoPoint(lat: 11.5630, lon: 124.3970)),
            ("naval", GeoPoint(lat: 11.5630, lon: 124.3970)),
            ("samar", GeoPoint(lat: 11.7750, lon: 124.8860)),
            ("catbalogan", GeoPoint(lat: 11.7750, lon: 124.8860)),
            ("eastern samar", GeoPoint(lat: 11.6080, lon: 125.4320)),
            ("borongan", GeoPoint(lat: 11.6080, lon: 125.4320)),
            ("northern samar", GeoPoint(lat: 12.4980, lon: 124.6360)),
            ("catarman", GeoPoint(lat: 12.4980, lon: 124.6360)),
            ("ormoc", GeoPoint(lat: 11.0060, lon: 124.6070)),
            ("baybay", GeoPoint(lat: 10.6790, lon: 124.8010)),
            ("calbayog", GeoPoint(lat: 12.0670, lon: 124.5960)),

            // — Zamboanga Peninsula (IX) —
            ("zamboanga del norte", GeoPoint(lat: 8.5890, lon: 123.3410)),
            ("dipolog", GeoPoint(lat: 8.5890, lon: 123.3410)),
            ("dapitan", GeoPoint(lat: 8.6580, lon: 123.4230)),
            ("zamboanga del sur", GeoPoint(lat: 7.8260, lon: 123.4370)),
            ("pagadian", GeoPoint(lat: 7.8260, lon: 123.4370)),
            ("zamboanga sibugay", GeoPoint(lat: 7.7840, lon: 122.5860)),
            ("ipil", GeoPoint(lat: 7.7840, lon: 122.5860)),
            ("zamboanga", GeoPoint(lat: 6.9214, lon: 122.0790)),
            ("zamboanga city", GeoPoint(lat: 6.9214, lon: 122.0790)),

            // — Northern Mindanao (X) —
            ("bukidnon", GeoPoint(lat: 8.1570, lon: 125.1270)),
            ("malaybalay", GeoPoint(lat: 8.1570, lon: 125.1270)),
            ("valencia", GeoPoint(lat: 7.9040, lon: 125.0940)),
            ("camiguin", GeoPoint(lat: 9.2510, lon: 124.7150)),
            ("mambajao", GeoPoint(lat: 9.2510, lon: 124.7150)),
            ("lanao del norte", GeoPoint(lat: 7.9910, lon: 123.9490)),
            ("tubod", GeoPoint(lat: 7.9910, lon: 123.9490)),
            ("iligan", GeoPoint(lat: 8.2280, lon: 124.2450)),
            ("misamis occidental", GeoPoint(lat: 8.4850, lon: 123.8050)),
            ("oroquieta", GeoPoint(lat: 8.4850, lon: 123.8050)),
            ("ozamiz", GeoPoint(lat: 8.1460, lon: 123.8440)),
            ("misamis oriental", GeoPoint(lat: 8.5090, lon: 124.6470)),
            ("cagayan de oro", GeoPoint(lat: 8.4542, lon: 124.6319)),
            ("cdo", GeoPoint(lat: 8.4542, lon: 124.6319)),
            ("gingoog", GeoPoint(lat: 8.8290, lon: 125.1000)),

            // — Davao Region (XI) —
            ("davao del norte", GeoPoint(lat: 7.4480, lon: 125.8090)),
            ("tagum", GeoPoint(lat: 7.4480, lon: 125.8090)),
            ("davao del sur", GeoPoint(lat: 6.7490, lon: 125.3570)),
            ("digos", GeoPoint(lat: 6.7490, lon: 125.3570)),
            ("davao", GeoPoint(lat: 7.1907, lon: 125.4553)),
            ("davao city", GeoPoint(lat: 7.1907, lon: 125.4553)),
            ("davao occidental", GeoPoint(lat: 6.4130, lon: 125.6130)),
            ("malita", GeoPoint(lat: 6.4130, lon: 125.6130)),
            ("davao oriental", GeoPoint(lat: 6.9550, lon: 126.2270)),
            ("mati", GeoPoint(lat: 6.9550, lon: 126.2270)),
            ("davao de oro", GeoPoint(lat: 7.6000, lon: 125.9660)),
            ("nabunturan", GeoPoint(lat: 7.6000, lon: 125.9660)),
            ("panabo", GeoPoint(lat: 7.3080, lon: 125.6840)),
            ("samal", GeoPoint(lat: 7.0530, lon: 125.7080)),

            // — SOCCSKSARGEN (XII) —
            ("north cotabato", GeoPoint(lat: 7.0080, lon: 125.0890)),
            ("kidapawan", GeoPoint(lat: 7.0080, lon: 125.0890)),
            ("cotabato", GeoPoint(lat: 7.2230, lon: 124.2460)),
            ("cotabato city", GeoPoint(lat: 7.2230, lon: 124.2460)),
            ("sarangani", GeoPoint(lat: 6.1030, lon: 125.2900)),
            ("alabel", GeoPoint(lat: 6.1030, lon: 125.2900)),
            ("south cotabato", GeoPoint(lat: 6.5030, lon: 124.8470)),
            ("koronadal", GeoPoint(lat: 6.5030, lon: 124.8470)),
            ("sultan kudarat", GeoPoint(lat: 6.6290, lon: 124.6050)),
            ("isulan", GeoPoint(lat: 6.6290, lon: 124.6050)),
            ("general santos", GeoPoint(lat: 6.1128, lon: 125.1717)),
            ("gensan", GeoPoint(lat: 6.1128, lon: 125.1717)),
            ("tacurong", GeoPoint(lat: 6.6920, lon: 124.6760)),
            ("midsayap", GeoPoint(lat: 7.1900, lon: 124.5300)),

            // — Caraga (XIII) —
            ("agusan del norte", GeoPoint(lat: 9.1230, lon: 125.5340)),
            ("cabadbaran", GeoPoint(lat: 9.1230, lon: 125.5340)),
            ("butuan", GeoPoint(lat: 8.9490, lon: 125.5410)),
            ("agusan del sur", GeoPoint(lat: 8.6010, lon: 125.9150)),
            ("prosperidad", GeoPoint(lat: 8.6010, lon: 125.9150)),
            ("surigao del norte", GeoPoint(lat: 9.7890, lon: 125.4950)),
            ("surigao", GeoPoint(lat: 9.7890, lon: 125.4950)),
            ("surigao city", GeoPoint(lat: 9.7890, lon: 125.4950)),
            ("surigao del sur", GeoPoint(lat: 9.0780, lon: 126.1980)),
            ("tandag", GeoPoint(lat: 9.0780, lon: 126.1980)),
            ("dinagat", GeoPoint(lat: 10.0300, lon: 125.5900)),
            ("bislig", GeoPoint(lat: 8.2140, lon: 126.3170)),
            ("bayugan", GeoPoint(lat: 8.7150, lon: 125.7480)),

            // — BARMM —
            ("maguindanao", GeoPoint(lat: 7.2230, lon: 124.2460)),
            ("lanao del sur", GeoPoint(lat: 8.0000, lon: 124.2930)),
            ("marawi", GeoPoint(lat: 8.0000, lon: 124.2930)),
            ("basilan", GeoPoint(lat: 6.7040, lon: 121.9700)),
            ("isabela city", GeoPoint(lat: 6.7040, lon: 121.9700)),
            ("sulu", GeoPoint(lat: 6.0520, lon: 121.0020)),
            ("jolo", GeoPoint(lat: 6.0520, lon: 121.0020)),
            ("tawi-tawi", GeoPoint(lat: 5.0290, lon: 119.7730)),
            ("bongao", GeoPoint(lat: 5.0290, lon: 119.7730)),
        ],
        uniquingKeysWith: { first, _ in first }
    )

    func route(from origin: String, to destination: String) -> RouteResult? {
        guard let a = Self.lookup(origin), let b = Self.lookup(destination) else { return nil }
        let straight = Self.haversineKm(a, b)
        let road = (straight * windingFactor)
        let rounded = (road * 10).rounded() / 10
        return RouteResult(distanceKm: rounded, isEstimated: true)
    }

    /// Fuzzy place lookup — exact key, then a substring match either way. Static so
    /// the NL query parser can reuse the same gazetteer.
    static func lookup(_ query: String) -> GeoPoint? {
        let key = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }
        if let exact = places[key] { return exact }
        // Deterministic (not Dictionary iteration order): prefer the longest known
        // place name contained in the query (e.g. "cebu" out of "cebu city trip").
        if let longest = places.keys.filter({ key.contains($0) }).max(by: { $0.count < $1.count }) {
            return places[longest]
        }
        // Otherwise the shortest place name that contains the query (prefix typing).
        if let shortest = places.keys.filter({ $0.contains(key) }).min(by: { $0.count < $1.count }) {
            return places[shortest]
        }
        return nil
    }

    /// Whether a free-text fragment names a known place.
    static func isPlace(_ query: String) -> Bool { lookup(query) != nil }

    /// Whether a single word is itself a gazetteer key (e.g. "makati", "pampanga").
    /// Used by the NL parser to avoid merging two adjacent places into one phrase.
    static func isPlaceKey(_ word: String) -> Bool {
        places.keys.contains(word.lowercased())
    }

    /// Great-circle distance in kilometres.
    static func haversineKm(_ a: GeoPoint, _ b: GeoPoint) -> Double {
        let earthRadiusKm = 6371.0
        let dLat = (b.lat - a.lat) * .pi / 180
        let dLon = (b.lon - a.lon) * .pi / 180
        let lat1 = a.lat * .pi / 180
        let lat2 = b.lat * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2)
            + sin(dLon / 2) * sin(dLon / 2) * cos(lat1) * cos(lat2)
        return earthRadiusKm * 2 * atan2(sqrt(h), sqrt(1 - h))
    }
}
