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

        // ── Metro Manila — malls, landmarks, universities, hospitals, hubs ──
        g("Metro Manila", [
            ("SM Mall of Asia", 14.5352, 120.9822, ["moa", "mall of asia", "sm moa"]),
            ("SM Megamall", 14.5847, 121.0567, ["megamall"]),
            ("SM North EDSA", 14.6567, 121.0300, ["sm north", "sm north edsa"]),
            ("SM City Manila", 14.5896, 120.9822, ["sm manila"]),
            ("SM Fairview", 14.7340, 121.0590, []),
            ("SM Southmall", 14.4290, 121.0000, ["sm southmall"]),
            ("Glorietta", 14.5527, 121.0246, []),
            ("Greenbelt", 14.5520, 121.0210, ["greenbelt makati"]),
            ("Trinoma", 14.6535, 121.0330, ["trinoma mall"]),
            ("Ayala Vertis North", 14.6540, 121.0400, ["vertis north"]),
            ("Robinsons Galleria", 14.5920, 121.0570, ["robinsons galleria"]),
            ("Robinsons Place Manila", 14.5770, 120.9850, ["robinsons manila", "robinsons ermita"]),
            ("Gateway Mall", 14.6220, 121.0530, ["gateway araneta", "araneta city", "araneta"]),
            ("Uptown Mall BGC", 14.5540, 121.0500, ["uptown bgc", "uptown mall"]),
            ("Bonifacio High Street", 14.5500, 121.0480, ["high street", "bgc high street"]),
            ("Market! Market!", 14.5490, 121.0560, ["market market"]),
            ("Shangri-La Plaza", 14.5820, 121.0560, ["shangri-la plaza", "shang"]),
            ("The Podium", 14.5850, 121.0590, ["podium"]),
            ("Ayala Malls Manila Bay", 14.5230, 120.9930, ["manila bay mall"]),
            ("Alabang Town Center", 14.4230, 121.0290, ["atc", "alabang town center"]),
            ("Festival Mall", 14.4180, 121.0410, ["festival mall"]),
            ("Venice Grand Canal Mall", 14.5390, 121.0560, ["venice mall", "venice grand canal", "mckinley"]),
            ("Power Plant Mall", 14.5650, 121.0360, ["rockwell", "power plant"]),
            ("Ayala Malls Circuit", 14.5720, 121.0130, ["circuit makati"]),
            ("Fisher Mall", 14.6300, 121.0000, ["fisher mall"]),
            ("Lucky Chinatown", 14.6030, 120.9740, ["lucky chinatown"]),
            ("Intramuros", 14.5900, 120.9750, []),
            ("Rizal Park", 14.5825, 120.9797, ["luneta"]),
            ("Manila Ocean Park", 14.5790, 120.9730, ["ocean park"]),
            ("National Museum", 14.5870, 120.9810, []),
            ("Divisoria", 14.6030, 120.9700, ["divisoria market"]),
            ("Binondo", 14.6000, 120.9750, ["chinatown"]),
            ("Quiapo", 14.5980, 120.9840, ["quiapo church"]),
            ("Star City", 14.5540, 120.9880, []),
            ("Cultural Center", 14.5540, 120.9800, ["ccp", "cultural center of the philippines"]),
            ("Maginhawa", 14.6450, 121.0620, ["maginhawa street"]),
            ("Tomas Morato", 14.6320, 121.0350, []),
            ("Timog Avenue", 14.6350, 121.0330, ["timog"]),
            ("Quezon Memorial Circle", 14.6510, 121.0490, ["qc circle", "quezon circle"]),
            ("Shaw Boulevard", 14.5810, 121.0530, ["shaw", "shaw blvd"]),
            ("Guadalupe", 14.5670, 121.0440, ["guadalupe makati"]),
            ("Magallanes", 14.5420, 121.0160, []),
            ("UP Diliman", 14.6540, 121.0680, ["up diliman", "university of the philippines"]),
            ("Ateneo de Manila", 14.6400, 121.0770, ["ateneo", "admu"]),
            ("De La Salle University", 14.5645, 120.9930, ["dlsu", "la salle", "de la salle"]),
            ("University of Santo Tomas", 14.6100, 120.9890, ["ust", "ust manila"]),
            ("Far Eastern University", 14.6030, 120.9880, ["feu"]),
            ("PUP Manila", 14.5980, 121.0110, ["pup", "polytechnic university"]),
            ("St. Luke's BGC", 14.5540, 121.0450, ["st lukes bgc", "st. luke's bgc", "st lukes global"]),
            ("St. Luke's QC", 14.6230, 121.0230, ["st lukes qc", "st. luke's qc"]),
            ("Makati Medical Center", 14.5610, 121.0180, ["makati med", "makatimed"]),
            ("The Medical City", 14.5890, 121.0680, ["medical city"]),
            ("Philippine General Hospital", 14.5780, 120.9860, ["pgh"]),
            ("Cardinal Santos Medical Center", 14.6010, 121.0490, ["cardinal santos"]),
            ("PITX", 14.5090, 120.9930, ["pitx", "paranaque integrated terminal"]),
            ("Malacañang Palace", 14.5940, 120.9940, ["malacanang", "malacañang"]),
            ("LTO East Avenue", 14.6480, 121.0500, ["lto main", "lto east ave"]),
            ("DFA Aseana", 14.5290, 120.9910, ["dfa", "dfa aseana"]),
            ("NAIA Terminal 3", 14.5090, 121.0170, ["naia", "naia t3", "naia terminal 3", "airport", "manila airport"]),
            ("Manila North Harbor", 14.6080, 120.9640, ["north harbor", "pier 4", "manila pier"]),
            ("Manila South Harbor", 14.5870, 120.9670, ["south harbor"]),
        ])

        // ── Airports & seaports (province subtitles → correct island mapping) ──
        g("Pampanga", [
            ("Clark International Airport", 15.1860, 120.5600, ["clark airport", "clark international", "dmia"]),
        ])
        g("Cebu", [
            ("Mactan-Cebu International Airport", 10.3075, 123.9790, ["mactan airport", "cebu airport", "mactan-cebu"]),
            ("Cebu Port", 10.2980, 123.9110, ["cebu port", "cebu pier", "cebu pier 1"]),
        ])
        g("Davao City", [
            ("Davao International Airport", 7.1255, 125.6460, ["davao airport", "francisco bangoy"]),
            ("Davao Port", 7.1150, 125.6560, ["davao port", "sasa port"]),
        ])
        g("Iloilo", [
            ("Iloilo International Airport", 10.8330, 122.4930, ["iloilo airport"]),
            ("Iloilo Port", 10.6960, 122.5810, ["iloilo port"]),
        ])
        g("Negros Occidental", [
            ("Bacolod-Silay Airport", 10.7760, 123.0150, ["bacolod airport", "silay airport"]),
            ("Bacolod Port", 10.6100, 122.9600, ["bacolod port"]),
        ])
        g("Negros Oriental", [
            ("Dumaguete Airport", 9.3340, 123.3000, ["dumaguete airport"]),
            ("Dumaguete Port", 9.3070, 123.3080, ["dumaguete port"]),
        ])
        g("Aklan", [
            ("Kalibo International Airport", 11.6790, 122.3760, ["kalibo airport"]),
            ("Caticlan Airport", 11.9245, 121.9540, ["caticlan airport", "boracay airport"]),
            ("Caticlan Jetty Port", 11.9300, 121.9560, ["caticlan", "caticlan jetty", "caticlan port"]),
            ("Boracay", 11.9670, 121.9240, ["boracay island"]),
        ])
        g("Palawan", [
            ("Puerto Princesa Airport", 9.7420, 118.7590, ["puerto princesa airport"]),
            ("Puerto Princesa Port", 9.7390, 118.7480, ["puerto princesa port"]),
        ])
        g("Leyte", [
            ("Tacloban Airport", 11.2280, 125.0280, ["tacloban airport"]),
            ("Ormoc Port", 11.0060, 124.6070, ["ormoc port"]),
        ])
        g("Bohol", [
            ("Bohol-Panglao Airport", 9.5570, 123.7700, ["panglao airport", "bohol airport", "tagbilaran airport"]),
            ("Tagbilaran Port", 9.6470, 123.8560, ["tagbilaran port"]),
        ])
        g("Zamboanga City", [
            ("Zamboanga Airport", 6.9220, 122.0600, ["zamboanga airport"]),
        ])
        g("South Cotabato", [
            ("General Santos Airport", 6.0580, 125.0960, ["gensan airport", "general santos airport"]),
        ])
        g("Albay", [
            ("Legazpi Airport", 13.1580, 123.7350, ["legazpi airport"]),
        ])
        g("Agusan del Norte", [
            ("Butuan Airport", 8.9510, 125.4790, ["butuan airport", "bancasi"]),
        ])
        g("Batanes", [
            ("Basco Airport", 20.4510, 121.9800, ["basco airport"]),
        ])
        g("Surigao del Norte", [
            ("Sayak Airport (Siargao)", 9.8590, 126.0140, ["siargao airport", "sayak airport"]),
            ("Lipata Port", 9.8250, 125.4500, ["lipata"]),
        ])
        g("Misamis Oriental", [
            ("Cagayan de Oro Port", 8.5010, 124.6580, ["cdo port", "macabalan"]),
        ])
        g("Batangas", [
            ("Batangas Port", 13.7560, 121.0480, ["batangas port", "batangas pier"]),
        ])
        g("Sorsogon", [
            ("Matnog Port", 12.5870, 124.0850, ["matnog"]),
        ])
        g("Northern Samar", [
            ("Allen Port", 12.5060, 124.2810, ["allen"]),
        ])
        g("Southern Leyte", [
            ("Liloan Port", 10.3560, 125.1450, ["liloan port"]),
        ])
        g("Laguna", [
            ("Enchanted Kingdom", 14.3200, 121.0670, ["enchanted kingdom", "ek"]),
        ])

        // ── Local coverage: Central/Northern Luzon (verified via MKLocalSearch) ──
        g("Pampanga", [
            ("SM Pampanga", 15.05269, 120.69709, ["sm pampanga", "sm san fernando", "sm sf"]),
            ("SM Clark", 15.16892, 120.58014, ["sm clark", "sm city clark"]),
            ("Marquee Mall", 15.16280, 120.60984, ["marquee", "marquee mall"]),
            ("Nepo Mall", 15.13505, 120.58855, ["nepo", "nepo mall"]),
            ("Robinsons Starmills", 15.04863, 120.69843, ["starmills", "robinsons starmills"]),
            ("Dau Bus Terminal", 15.17902, 120.58906, ["dau", "dau terminal", "dau mabalacat"]),
            ("Clark Freeport Zone", 15.17896, 120.52901, ["clark", "clark freeport", "clark zone"]),
            ("Angeles City Hall", 15.16554, 120.60802, ["angeles city hall"]),
            ("Holy Angel University", 15.13328, 120.59002, ["hau", "holy angel"]),
            ("Angeles University Foundation", 15.14499, 120.59432, ["auf", "angeles university"]),
            ("Laus Group Event Center", 15.04803, 120.68821, ["laus group", "lgec"]),
            ("Puregold Angeles", 15.16060, 120.59142, ["puregold angeles"]),
            ("Waltermart Pampanga", 15.04835, 120.66860, ["waltermart pampanga", "waltermart san fernando"]),
            ("Jenra Mall", 15.13644, 120.58790, ["jenra", "jenra mall"]),
            ("Fields Avenue", 15.16651, 120.58339, ["fields", "fields avenue"]),
            ("Balibago", 15.16258, 120.59125, ["balibago"]),
            ("Magalang", 15.21393, 120.66186, []),
            ("Mexico", 15.06443, 120.71885, ["mexico pampanga"]),
            ("Arayat", 15.15047, 120.77119, []),
            ("Porac", 15.07305, 120.54085, []),
            ("Floridablanca", 14.97541, 120.52856, []),
            ("Guagua", 14.96188, 120.63108, []),
            ("Lubao", 14.90939, 120.54987, []),
            ("Sasmuan", 14.93657, 120.62230, []),
            ("Bacolor", 14.99798, 120.65206, []),
            ("Candaba", 15.09253, 120.82728, []),
            ("Apalit", 14.95289, 120.77227, []),
        ])
        g("Bulacan", [
            ("SM Marilao", 14.75394, 120.95567, ["sm marilao"]),
            ("SM Baliwag", 14.96039, 120.89053, ["sm baliwag", "sm baliuag"]),
            ("Robinsons Malolos", 14.84997, 120.82363, ["robinsons malolos"]),
            ("Malolos City Hall", 14.86075, 120.81022, ["malolos city hall"]),
            ("Malolos Cathedral", 14.84245, 120.81158, ["malolos cathedral"]),
            ("Barasoain Church", 14.84637, 120.81232, ["barasoain"]),
            ("Marilao", 14.76033, 120.96233, []),
            ("Bocaue", 14.79948, 120.92063, []),
            ("Guiguinto", 14.84134, 120.86697, []),
            ("Plaridel", 14.88608, 120.85681, ["plaridel bulacan"]),
            ("Pulilan", 14.90356, 120.84576, []),
            ("Calumpit", 14.91577, 120.76717, []),
            ("Bulacan Provincial Capitol", 14.85627, 120.81495, ["bulacan capitol"]),
        ])
        g("Tarlac", [
            ("SM Tarlac", 15.47705, 120.59464, ["sm tarlac"]),
            ("Robinsons Tarlac", 15.43125, 120.59942, ["robinsons tarlac", "robinsons luisita"]),
            ("Paniqui", 15.66780, 120.58099, []),
            ("La Paz Tarlac", 15.44188, 120.72852, []),
            ("Camiling", 15.68557, 120.41232, []),
            ("Tarlac Provincial Capitol", 15.48028, 120.58800, ["tarlac capitol"]),
        ])
        g("Nueva Ecija", [
            ("SM Cabanatuan", 15.46715, 120.95499, ["sm cabanatuan"]),
            ("Robinsons Cabanatuan", 15.45986, 120.94986, ["robinsons cabanatuan"]),
            ("Palayan City", 15.54550, 121.08710, ["palayan"]),
            ("San Jose City", 15.79026, 120.98925, ["san jose nueva ecija"]),
            ("Nueva Ecija Provincial Capitol", 15.55646, 121.09476, ["nueva ecija capitol"]),
        ])
        g("Zambales", [
            ("Subic Bay Freeport Zone", 14.78899, 120.27987, ["sbma", "subic freeport", "subic bay"]),
            ("San Antonio Zambales", 14.94971, 120.08859, []),
            ("San Narciso Zambales", 15.01565, 120.08192, []),
            ("Harbor Point", 14.82505, 120.28033, ["harbor point", "harbour point"]),
        ])
        g("Bataan", [
            ("SM City Bataan", 14.68328, 120.53723, ["sm bataan"]),
            ("Orion", 14.61976, 120.57789, []),
            ("Limay", 14.56143, 120.59547, []),
            ("Dinalupihan", 14.86890, 120.46390, []),
        ])
        g("Pangasinan", [
            ("SM Dagupan", 16.04435, 120.34354, ["sm dagupan", "sm center dagupan"]),
            ("Robinsons Pangasinan", 16.02281, 120.35882, ["robinsons pangasinan", "robinsons calasiao"]),
            ("San Carlos City Pangasinan", 15.92679, 120.34575, []),
            ("Mangaldan", 16.07021, 120.40258, []),
            ("Binalonan", 16.04534, 120.59431, []),
            ("Calasiao", 16.00967, 120.35423, []),
        ])
        g("La Union", [
            ("CSI City Mall La Union", 16.62930, 120.32262, ["csi mall", "csi la union", "sm san fernando la union"]),
            ("Bauang", 16.52879, 120.32886, []),
            ("San Juan La Union", 16.67135, 120.33688, ["san juan surf", "elyu"]),
        ])
        g("Benguet", [
            ("SM Baguio", 16.40897, 120.59939, ["sm baguio"]),
            ("Session Road", 16.40636, 120.60107, ["session road"]),
            ("Burnham Park", 16.41107, 120.59540, ["burnham"]),
            ("Camp John Hay", 16.39670, 120.61600, ["john hay"]),
            ("The Mansion", 16.41239, 120.62149, ["mansion house"]),
            ("Mines View Park", 16.42288, 120.62368, ["mines view"]),
            ("Wright Park", 16.41514, 120.61859, []),
            ("Baguio Cathedral", 16.41278, 120.59854, []),
            ("Abanao Square", 16.41402, 120.59414, ["abanao"]),
            ("Porta Vaga Mall", 16.41197, 120.59859, ["porta vaga"]),
            ("Baguio General Hospital", 16.40110, 120.59613, ["bghmc", "baguio general"]),
            ("Philippine Military Academy", 16.36074, 120.61882, ["pma", "pma baguio"]),
            ("UP Baguio", 16.40591, 120.59830, ["up baguio"]),
        ])

        return out
    }
}
