//
//  GazetteerData.swift
//  aigos
//
//  The bundled offline place database: Philippine provinces, major cities and
//  municipalities, Metro Manila districts/barangays, and common landmark/road
//  aliases (BGC, EDSA, NLEX, SLEX, C5, …). Each entry has a display title, a
//  subtitle (province/region), a coordinate, and optional aliases.
//
//  Coordinates are approximate — distance is an estimate. Not every one of the
//  country's ~1,600 municipalities is listed; coverage is all provinces + the
//  major/urbanised localities people actually search for.
//

import Foundation

enum GazetteerData {

    static let entries: [GazetteerEntry] = build()

    private static func build() -> [GazetteerEntry] {
        var out: [GazetteerEntry] = []
        func g(_ subtitle: String, _ rows: [(String, Double, Double, [String])]) {
            for (title, lat, lon, aliases) in rows {
                out.append(GazetteerEntry(
                    title: title, subtitle: subtitle,
                    point: GeoPoint(lat: lat, lon: lon),
                    aliases: aliases.map { $0.lowercased() }
                ))
            }
        }

        // ── Metro Manila (cities, districts, landmarks, roads) ──
        g("Metro Manila", [
            ("Manila", 14.5995, 120.9842, ["metro manila"]),
            ("Quezon City", 14.6760, 121.0437, ["qc"]),
            ("Makati", 14.5547, 121.0244, []),
            ("Bonifacio Global City", 14.5507, 121.0494, ["bgc", "the fort", "fort bonifacio"]),
            ("Taguig", 14.5176, 121.0509, []),
            ("Pasig", 14.5764, 121.0851, []),
            ("Ortigas", 14.5866, 121.0596, ["ortigas center"]),
            ("Mandaluyong", 14.5794, 121.0359, []),
            ("San Juan", 14.6019, 121.0355, []),
            ("Greenhills", 14.6030, 121.0500, []),
            ("Marikina", 14.6507, 121.1029, []),
            ("Cubao", 14.6190, 121.0530, []),
            ("Eastwood", 14.6093, 121.0800, ["eastwood city"]),
            ("Katipunan", 14.6390, 121.0730, []),
            ("Novaliches", 14.7160, 121.0390, []),
            ("Fairview", 14.7300, 121.0570, []),
            ("Caloocan", 14.6577, 120.9727, []),
            ("Malabon", 14.6570, 120.9569, []),
            ("Navotas", 14.6664, 120.9422, []),
            ("Valenzuela", 14.7011, 120.9830, []),
            ("Pasay", 14.5378, 121.0014, []),
            ("Parañaque", 14.4793, 121.0198, ["paranaque"]),
            ("Las Piñas", 14.4453, 120.9833, ["las pinas"]),
            ("Muntinlupa", 14.4081, 121.0415, []),
            ("Alabang", 14.4188, 121.0417, []),
            ("Pateros", 14.5455, 121.0685, []),
            ("Binondo", 14.6000, 120.9750, []),
            ("Divisoria", 14.6010, 120.9700, []),
            ("Ermita", 14.5820, 120.9820, []),
            ("Malate", 14.5680, 120.9880, []),
            ("Intramuros", 14.5900, 120.9750, []),
            ("Quiapo", 14.5990, 120.9840, []),
            ("Poblacion", 14.5650, 121.0290, ["poblacion makati"]),
            ("Salcedo Village", 14.5590, 121.0230, ["salcedo"]),
            ("Legazpi Village", 14.5560, 121.0190, ["legaspi village"]),
            ("Trinoma", 14.6540, 121.0330, []),
            ("EDSA", 14.5800, 121.0560, []),
            ("C5", 14.5700, 121.0650, ["c5 road"]),
            ("NLEX", 14.8000, 120.8500, ["north luzon expressway"]),
            ("SLEX", 14.4300, 121.0400, ["south luzon expressway"]),
        ])

        // ── Cordillera (CAR) ──
        g("Benguet", [("Baguio", 16.4023, 120.5960, []), ("La Trinidad", 16.4550, 120.5870, ["benguet"])])
        g("Cordillera", [
            ("Abra", 17.5960, 120.6180, ["bangued"]),
            ("Apayao", 18.0180, 121.1830, []),
            ("Ifugao", 16.8330, 121.1000, ["lagawe"]),
            ("Banaue", 16.9100, 121.0580, []),
            ("Sagada", 17.0840, 120.9010, []),
            ("Kalinga", 17.4090, 121.4440, ["tabuk"]),
            ("Mountain Province", 17.0890, 120.9760, ["bontoc"]),
        ])

        // ── Ilocos Region (I) ──
        g("Ilocos Norte", [("Laoag", 18.1978, 120.5936, ["ilocos norte"]), ("Batac", 18.0550, 120.5660, [])])
        g("Ilocos Sur", [("Vigan", 17.5747, 120.3869, ["ilocos sur", "ilocos"]), ("Candon", 17.1950, 120.4520, [])])
        g("La Union", [("San Fernando La Union", 16.6159, 120.3166, ["la union"]), ("Agoo", 16.3150, 120.3690, [])])
        g("Pangasinan", [
            ("Lingayen", 16.0217, 120.2320, ["pangasinan"]),
            ("Dagupan", 16.0431, 120.3339, []),
            ("Urdaneta", 15.9760, 120.5710, []),
            ("San Carlos Pangasinan", 15.9280, 120.3490, ["san carlos"]),
            ("Alaminos", 16.1560, 119.9810, []),
            ("Bolinao", 16.3860, 119.8900, []),
        ])

        // ── Cagayan Valley (II) ──
        g("Cagayan", [("Tuguegarao", 17.6132, 121.7270, ["cagayan"]), ("Aparri", 18.3540, 121.6410, [])])
        g("Isabela", [("Ilagan", 17.1490, 121.8890, ["isabela"]), ("Cauayan", 16.9350, 121.7710, []), ("Santiago", 16.6880, 121.5480, [])])
        g("Nueva Vizcaya", [("Bayombong", 16.4820, 121.1490, ["nueva vizcaya"])])
        g("Quirino", [("Cabarroguis", 16.5710, 121.5250, ["quirino"])])
        g("Batanes", [("Basco", 20.4490, 121.9700, ["batanes"])])

        // ── Central Luzon (III) ──
        g("Pampanga", [
            ("San Fernando", 15.0286, 120.6898, ["pampanga"]),
            ("Angeles", 15.1450, 120.5887, []),
            ("Mabalacat", 15.2210, 120.5750, []),
            ("Clark", 15.1855, 120.5601, ["clark freeport"]),
        ])
        g("Bulacan", [
            ("Malolos", 14.8433, 120.8113, ["bulacan"]),
            ("Meycauayan", 14.7360, 120.9600, []),
            ("San Jose del Monte", 14.8139, 121.0453, ["sjdm"]),
            ("Baliuag", 14.9550, 120.8960, []),
        ])
        g("Nueva Ecija", [("Palayan", 15.5410, 121.0790, ["nueva ecija"]), ("Cabanatuan", 15.4869, 120.9675, []), ("Gapan", 15.3080, 120.9470, [])])
        g("Tarlac", [("Tarlac City", 15.4755, 120.5960, ["tarlac"]), ("Capas", 15.3340, 120.5920, [])])
        g("Zambales", [("Iba", 15.3280, 119.9780, ["zambales"]), ("Olongapo", 14.8292, 120.2828, []), ("Subic", 14.8797, 120.2350, [])])
        g("Bataan", [("Balanga", 14.6760, 120.5360, ["bataan"]), ("Mariveles", 14.4330, 120.4880, [])])
        g("Aurora", [("Baler", 15.7580, 121.5610, ["aurora"])])

        // ── CALABARZON (IV-A) ──
        g("Cavite", [
            ("Cavite City", 14.4791, 120.8970, ["cavite"]),
            ("Trece Martires", 14.2820, 120.8680, []),
            ("Bacoor", 14.4590, 120.9490, []),
            ("Dasmariñas", 14.3290, 120.9370, ["dasmarinas"]),
            ("Imus", 14.4290, 120.9370, []),
            ("General Trias", 14.3860, 120.8810, []),
            ("Tagaytay", 14.1153, 120.9621, []),
            ("Kawit", 14.4440, 120.9040, []),
        ])
        g("Laguna", [
            ("Santa Cruz Laguna", 14.2820, 121.4160, ["laguna", "santa cruz"]),
            ("Calamba", 14.2117, 121.1653, []),
            ("Santa Rosa", 14.3122, 121.1114, []),
            ("San Pablo", 14.0680, 121.3250, []),
            ("Biñan", 14.3330, 121.0810, ["binan"]),
            ("Cabuyao", 14.2470, 121.1360, []),
            ("Los Baños", 14.1700, 121.2410, ["los banos"]),
        ])
        g("Batangas", [
            ("Batangas City", 13.7565, 121.0583, ["batangas"]),
            ("Lipa", 13.9411, 121.1622, []),
            ("Tanauan", 14.0860, 121.1490, []),
            ("Nasugbu", 14.0720, 120.6320, []),
            ("Lemery", 13.8830, 120.9150, []),
        ])
        g("Quezon", [("Lucena", 13.9373, 121.6170, ["quezon province"]), ("Tayabas", 14.0250, 121.5920, [])])
        g("Rizal", [("Antipolo", 14.5932, 121.1760, ["rizal"]), ("Cainta", 14.5780, 121.1220, []), ("Taytay", 14.5690, 121.1320, [])])

        // ── MIMAROPA (IV-B) ──
        g("Occidental Mindoro", [("Mamburao", 13.2240, 120.5960, ["occidental mindoro"])])
        g("Oriental Mindoro", [("Calapan", 13.4110, 121.1800, ["oriental mindoro", "mindoro"]), ("Puerto Galera", 13.5030, 120.9540, [])])
        g("Marinduque", [("Boac", 13.4470, 121.8400, ["marinduque"])])
        g("Romblon", [("Romblon", 12.5750, 122.2710, [])])
        g("Palawan", [("Puerto Princesa", 9.7390, 118.7350, ["palawan"]), ("Coron", 12.0050, 120.2040, []), ("El Nido", 11.1960, 119.3910, [])])

        // ── Bicol (V) ──
        g("Camarines Norte", [("Daet", 14.1120, 122.9550, ["camarines norte"])])
        g("Camarines Sur", [("Naga", 13.6218, 123.1948, ["camarines sur", "bicol"]), ("Pili", 13.5850, 123.2740, []), ("Iriga", 13.4270, 123.4110, [])])
        g("Albay", [("Legazpi", 13.1391, 123.7438, ["albay", "legaspi"]), ("Tabaco", 13.3590, 123.7330, []), ("Ligao", 13.2320, 123.5170, [])])
        g("Sorsogon", [("Sorsogon City", 12.9740, 124.0060, ["sorsogon"])])
        g("Catanduanes", [("Virac", 13.5850, 124.2380, ["catanduanes"])])
        g("Masbate", [("Masbate City", 12.3660, 123.6210, ["masbate"])])

        // ── Western Visayas (VI) ──
        g("Aklan", [("Kalibo", 11.7080, 122.3660, ["aklan"]), ("Boracay", 11.9670, 121.9240, [])])
        g("Antique", [("San Jose de Buenavista", 10.7440, 121.9390, ["antique"])])
        g("Capiz", [("Roxas", 11.5850, 122.7510, ["capiz"])])
        g("Guimaras", [("Jordan", 10.5950, 122.5940, ["guimaras"])])
        g("Iloilo", [("Iloilo City", 10.7202, 122.5621, ["iloilo"]), ("Passi", 11.1080, 122.6420, [])])
        g("Negros Occidental", [("Bacolod", 10.6407, 122.9689, ["negros occidental"]), ("Bago", 10.5380, 122.8360, []), ("Silay", 10.7980, 122.9750, [])])

        // ── Central Visayas (VII) ──
        g("Bohol", [("Tagbilaran", 9.6470, 123.8540, ["bohol"]), ("Panglao", 9.5790, 123.7480, [])])
        g("Cebu", [
            ("Cebu City", 10.3157, 123.8854, ["cebu"]),
            ("Mandaue", 10.3230, 123.9220, []),
            ("Lapu-Lapu", 10.3100, 123.9490, ["mactan"]),
            ("Talisay Cebu", 10.2450, 123.8490, ["talisay"]),
            ("Toledo", 10.3770, 123.6390, []),
            ("Carcar", 10.1060, 123.6400, []),
        ])
        g("Negros Oriental", [("Dumaguete", 9.3070, 123.3080, ["negros oriental"])])
        g("Siquijor", [("Siquijor", 9.2140, 123.5150, [])])

        // ── Eastern Visayas (VIII) ──
        g("Leyte", [("Tacloban", 11.2440, 125.0040, ["leyte"]), ("Ormoc", 11.0060, 124.6070, []), ("Baybay", 10.6790, 124.8010, [])])
        g("Southern Leyte", [("Maasin", 10.1330, 124.8440, ["southern leyte"])])
        g("Biliran", [("Naval", 11.5630, 124.3970, ["biliran"])])
        g("Samar", [("Catbalogan", 11.7750, 124.8860, ["samar", "western samar"]), ("Calbayog", 12.0670, 124.5960, [])])
        g("Eastern Samar", [("Borongan", 11.6080, 125.4320, ["eastern samar"])])
        g("Northern Samar", [("Catarman", 12.4980, 124.6360, ["northern samar"])])

        // ── Zamboanga Peninsula (IX) ──
        g("Zamboanga del Norte", [("Dipolog", 8.5890, 123.3410, ["zamboanga del norte"]), ("Dapitan", 8.6580, 123.4230, [])])
        g("Zamboanga del Sur", [("Pagadian", 7.8260, 123.4370, ["zamboanga del sur"])])
        g("Zamboanga Sibugay", [("Ipil", 7.7840, 122.5860, ["zamboanga sibugay"])])
        g("Zamboanga City", [("Zamboanga", 6.9214, 122.0790, ["zamboanga city"])])

        // ── Northern Mindanao (X) ──
        g("Bukidnon", [("Malaybalay", 8.1570, 125.1270, ["bukidnon"]), ("Valencia Bukidnon", 7.9040, 125.0940, ["valencia"])])
        g("Camiguin", [("Mambajao", 9.2510, 124.7150, ["camiguin"])])
        g("Lanao del Norte", [("Tubod", 7.9910, 123.9490, ["lanao del norte"]), ("Iligan", 8.2280, 124.2450, [])])
        g("Misamis Occidental", [("Oroquieta", 8.4850, 123.8050, ["misamis occidental"]), ("Ozamiz", 8.1460, 123.8440, [])])
        g("Misamis Oriental", [("Cagayan de Oro", 8.4542, 124.6319, ["misamis oriental", "cdo"]), ("Gingoog", 8.8290, 125.1000, [])])

        // ── Davao Region (XI) ──
        g("Davao del Norte", [("Tagum", 7.4480, 125.8090, ["davao del norte"]), ("Panabo", 7.3080, 125.6840, [])])
        g("Davao del Sur", [("Digos", 6.7490, 125.3570, ["davao del sur"])])
        g("Davao City", [("Davao", 7.1907, 125.4553, ["davao city"]), ("Samal", 7.0530, 125.7080, [])])
        g("Davao Oriental", [("Mati", 6.9550, 126.2270, ["davao oriental"])])
        g("Davao de Oro", [("Nabunturan", 7.6000, 125.9660, ["davao de oro", "compostela valley"])])
        g("Davao Occidental", [("Malita", 6.4130, 125.6130, ["davao occidental"])])

        // ── SOCCSKSARGEN (XII) ──
        g("Cotabato", [("Kidapawan", 7.0080, 125.0890, ["north cotabato"]), ("Cotabato City", 7.2230, 124.2460, ["cotabato"])])
        g("South Cotabato", [("Koronadal", 6.5030, 124.8470, ["south cotabato"]), ("General Santos", 6.1128, 125.1717, ["gensan"])])
        g("Sarangani", [("Alabel", 6.1030, 125.2900, ["sarangani"])])
        g("Sultan Kudarat", [("Isulan", 6.6290, 124.6050, ["sultan kudarat"]), ("Tacurong", 6.6920, 124.6760, [])])

        // ── Caraga (XIII) ──
        g("Agusan del Norte", [("Butuan", 8.9490, 125.5410, ["agusan del norte"]), ("Cabadbaran", 9.1230, 125.5340, [])])
        g("Agusan del Sur", [("Prosperidad", 8.6010, 125.9150, ["agusan del sur"]), ("Bayugan", 8.7150, 125.7480, [])])
        g("Surigao del Norte", [("Surigao", 9.7890, 125.4950, ["surigao del norte"])])
        g("Surigao del Sur", [("Tandag", 9.0780, 126.1980, ["surigao del sur"]), ("Bislig", 8.2140, 126.3170, [])])
        g("Dinagat Islands", [("San Jose Dinagat", 10.0300, 125.5900, ["dinagat"])])

        // ── BARMM ──
        g("Maguindanao", [("Maguindanao", 7.2230, 124.2460, [])])
        g("Lanao del Sur", [("Marawi", 8.0000, 124.2930, ["lanao del sur"])])
        g("Basilan", [("Isabela City", 6.7040, 121.9700, ["basilan"])])
        g("Sulu", [("Jolo", 6.0520, 121.0020, ["sulu"])])
        g("Tawi-Tawi", [("Bongao", 5.0290, 119.7730, ["tawi-tawi"])])

        return out
    }
}
