//
//  TalkToAigosView.swift
//  aigos
//
//  "Talk to aigos" natural-language trip queries (Section 7, Feature 07). Ask in
//  plain English — "How much to drive Pampanga to Manila in my Vios?" — and aigos
//  replies with a cost, then hands off to the calculator for the saved, learning
//  calculation. Understanding runs entirely on-device via the built-in offline
//  parser — works on every iPhone, no account, no internet.
//

import SwiftUI
import SwiftData
import UIKit

struct TalkToAigosView: View {
    private static let bottomID = "chatBottom"

    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \VehicleProfile.createdAt) private var vehicles: [VehicleProfile]
    @Query private var personalPlaces: [PersonalPlace]
    @Query(sort: \TripRecord.calculatedAt, order: .reverse) private var tripRecords: [TripRecord]
    @Query private var fuelLogs: [FuelLog]
    @Query private var trackedTrips: [TrackedTrip]
    @AppStorage("fuelUnit") private var fuelUnit: FuelUnit = .kmPerL

    @State private var messages: [ChatMessage] = []
    @State private var input = ""
    @State private var showingGate = false
    @State private var lastQuery: TripQuery?   // for conversational follow-ups

    private let suggestions = [
        "Manila to Batangas",
        "How's my driving?",
        "How can I save fuel?",
        "I just filled up",
        "Show my monthly report",
        "How accurate were my estimates?",
    ]

    var body: some View {
        ZStack {
            AigosBackground()

            VStack(spacing: 0) {
                header
                messageList
                inputBar
            }
        }
        .sheet(isPresented: $showingGate) { AIGateView() }
        .onAppear(perform: greetIfNeeded)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Space.md) {
            MascotView(size: 44, floating: true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Talk to aigos")
                    .rounded(20, weight: .bold)
                    .foregroundStyle(.white)
                Button { showingGate = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "cpu")
                            .font(.system(size: 10))
                        Text("\(AIAvailability.badgeText) · works offline")
                            .rounded(12, weight: .medium)
                        Image(systemName: "info.circle")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(Color.white.opacity(0.8))
                }
            }
            Spacer()
            Button("Done") { dismiss() }
                .rounded(16, weight: .semibold)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, Space.screen)
        .padding(.vertical, Space.md)
    }

    // MARK: - Messages

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Space.md) {
                    ForEach(messages) { message in
                        ChatBubble(message: message, onOpen: { draft in
                            appState.recalculate(draft)
                            dismiss()
                        }, onUseVehicle: { vehicle in
                            appState.addVehicle(vehicle)
                            dismiss()
                        })
                        .id(message.id)
                        .transition(.asymmetric(
                            insertion: .move(edge: message.role == .user ? .trailing : .leading)
                                .combined(with: .opacity),
                            removal: .opacity
                        ))
                    }

                    if messages.count <= 1 {
                        VStack(alignment: .leading, spacing: Space.sm) {
                            ForEach(suggestions, id: \.self) { s in
                                Button {
                                    send(s)
                                } label: {
                                    Text(s)
                                        .rounded(14, weight: .medium)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, Space.md)
                                        .padding(.vertical, 10)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.white.opacity(0.12), in: Capsule())
                                        .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, Space.sm)
                    }

                    // Invisible anchor at the true bottom of the content (below the
                    // last bubble AND the suggestion chips / action buttons), so
                    // scrollTo always lands at the real end.
                    Color.clear.frame(height: 1).id(Self.bottomID)
                }
                .padding(.horizontal, Space.screen)
                .padding(.vertical, Space.md)
            }
            // Auto-scroll only when NEW content appears — never while the user is
            // manually scrolling up to read history.
            .onChange(of: messages.count) { _, _ in scrollToBottom(proxy) }
            .onAppear { scrollToBottom(proxy, animated: false) }   // show latest on open
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                scrollToBottom(proxy)   // keep the newest message above the keyboard
            }
        }
    }

    /// Scroll to the bottom anchor, deferred one runloop so a just-inserted bubble
    /// (and any action buttons inside it) is laid out before we measure the end.
    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool = true) {
        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
            } else {
                proxy.scrollTo(Self.bottomID, anchor: .bottom)
            }
        }
    }

    // MARK: - Input

    private var inputBar: some View {
        HStack(spacing: Space.sm) {
            GlassField(placeholder: "Ask a trip…", text: $input)
            Button {
                send(input)
            } label: {
                Image(systemName: "arrow.up")
                    .rounded(18, weight: .bold)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Color.aigosAmber.opacity(input.trimmingCharacters(in: .whitespaces).isEmpty ? 0.55 : 1), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, Space.screen)
        .padding(.vertical, Space.md)
        .background(.ultraThinMaterial.opacity(0.001))
    }

    // MARK: - Logic

    private func greetIfNeeded() {
        guard messages.isEmpty else { return }
        messages.append(ChatMessage(
            role: .aigos,
            text: "Hi! I'm aigos 🚙 Ask me a trip in plain English — like “How much to drive Pampanga to Manila?”"
        ))
        #if DEBUG
        if let q = DebugSupport.talkQuery {
            DispatchQueue.main.async {
                send(q)
                if let q2 = DebugSupport.talkQuery2 { send(q2) }
            }
        }
        #endif
    }

    private func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        input = ""
        let response = reply(to: trimmed)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            messages.append(ChatMessage(role: .user, text: trimmed))
            messages.append(response)
        }
    }

    private func reply(to rawText: String) -> ChatMessage {
        // Rewrite common Filipino phrasings to the English patterns below.
        let text = TalkNormalizer.normalize(rawText)

        // Greetings / thanks / goodbye / confusion — quick, unambiguous replies.
        if let smalltalk = TalkSmallTalk.quickReply(for: text) {
            return ChatMessage(role: .aigos, text: smalltalk)
        }

        // v1.1 intents: log a fill-up, monthly report, estimate accuracy.
        if let fuel = fuelLogReply(text) { return ChatMessage(role: .aigos, text: fuel) }
        if let report = reportReply(text) { return ChatMessage(role: .aigos, text: report) }
        if let acc = accuracyReply(text) { return ChatMessage(role: .aigos, text: acc) }

        // Feature 4: driving score, personalized tips, cost-trend analysis.
        if let driving = drivingReply(text) { return ChatMessage(role: .aigos, text: driving) }
        if let tips = saveTipsReply(text) { return ChatMessage(role: .aigos, text: tips) }
        if let trend = costTrendReply(text) { return ChatMessage(role: .aigos, text: trend) }

        // "Will I make it to X on one tank?" — trip fuel vs tank capacity. Checked
        // before the trip/knowledge intents (it names a trip but isn't a cost query).
        if let oneTank = oneTankReply(text) {
            return ChatMessage(role: .aigos, text: oneTank)
        }
        // "How big is my Vios tank?" — tank capacity + full-tank cost.
        if let tank = tankSizeReply(text) {
            return ChatMessage(role: .aigos, text: tank)
        }

        // Cross-island trips (Manila → Cebu, Angeles → Davao) can't be driven end
        // to end — show the sea/air breakdown BEFORE the land-based intents so we
        // never quote an impossible continuous distance.
        if let cross = crossIslandReply(text) {
            return cross
        }

        // Knowledge base — fuel-economy tips, troubleshooting, culture, routes,
        // drive-vs-bus, CO2, best time to travel. Checked before trip parsing
        // because many of these questions also name a place.
        if let knowledge = KnowledgeBase.answer(for: text, vehicle: knowledgeVehicle()) {
            return ChatMessage(role: .aigos, text: knowledge)
        }

        // A full trip in the message starts (and remembers) a new context.
        if let query = TripQueryParser.parse(text, vehicles: vehicles, personalPlaces: personalPlaces) {
            lastQuery = query
            return estimate(for: query)
        }
        // Otherwise treat it as a follow-up modifying the previous trip.
        if let prev = lastQuery {
            let hints = TripQueryParser.hints(from: text)
            let vehicleName = matchedVehicleName(in: text)
            if FollowUp.isFollowUp(text, hints: hints, vehicleChanged: vehicleName != nil) {
                let merged = FollowUp.merge(previous: prev, hints: hints, vehicleName: vehicleName)
                lastQuery = merged
                return estimate(for: merged)
            }
        }
        // "What's my mileage?" → the default vehicle's efficiency in the user's unit.
        if let mine = myMileageReply(text) {
            return ChatMessage(role: .aigos, text: mine)
        }
        // Vehicle knowledge base — "what's the km/L of Vios?", "my car is a SUV",
        // "what SUVs are fuel efficient?". Efficiency figures follow the user's unit.
        if let answer = VehicleDatabase.answer(for: text, unit: fuelUnit) {
            let suggestion = (answer.efficiencyKmL != nil || answer.offersAddVehicle) ? answer : nil
            return ChatMessage(role: .aigos, text: answer.text, vehicleSuggestion: suggestion)
        }
        // Nothing matched — nudge to the calculator, or redirect if off-topic.
        return ChatMessage(role: .aigos, text: TalkSmallTalk.fallback(for: text))
    }

    /// Default-vehicle context so KnowledgeBase can personalise savings/CO2 math.
    private func knowledgeVehicle() -> KnowledgeBase.Vehicle? {
        guard let v = vehicles.first(where: \.isDefault) ?? vehicles.first else { return nil }
        return KnowledgeBase.Vehicle(
            name: v.name, efficiencyKmL: v.efficiencyKmL, fuelType: v.fuelType,
            pricePerLitre: PriceService.price(for: v.fuelType, in: context))
    }

    /// "What's my mileage / efficiency (in L/100km)?" → the default vehicle's
    /// stored efficiency, shown in the user's current unit.
    private func myMileageReply(_ text: String) -> String? {
        let q = text.lowercased()
        let cues = ["my mileage", "my efficiency", "my km/l", "my kml", "my fuel economy",
                    "my consumption", "my fuel efficiency", "my car's efficiency", "my car's mileage"]
        guard cues.contains(where: { q.contains($0) }) else { return nil }
        guard let v = vehicles.first(where: \.isDefault) ?? vehicles.first else {
            return "Add a vehicle first and I'll show its efficiency."
        }
        return "Your \(v.name) is set to \(fuelUnit.format(kmL: v.efficiencyKmL))."
    }

    /// Match a vehicle named anywhere in the text (for "same trip in my truck").
    private func matchedVehicleName(in text: String) -> String? {
        ownedVehicle(in: text)?.name
    }

    /// A vehicle the user owns, named anywhere in the text.
    private func ownedVehicle(in text: String) -> VehicleProfile? {
        let lower = text.lowercased()
        return vehicles.first { v in
            v.name.lowercased().split(separator: " ").contains { $0.count >= 3 && lower.contains($0) }
        }
    }

    // MARK: - v1.1 intents (fuel log / report / accuracy)

    /// "I just filled up 35 L at Shell for 2,520" → parse + save a FuelLog + confirm.
    private func fuelLogReply(_ text: String) -> String? {
        guard let draft = FuelLogParser.parse(text) else { return nil }
        guard let v = vehicles.first(where: \.isDefault) ?? vehicles.first else {
            return "Add a vehicle first, then tell me about your fill-up."
        }
        let liters = draft.liters ?? 0
        let cost = draft.totalCost ?? 0
        guard liters > 0 || cost > 0 else {
            return "Got it — how many litres and how much did it cost? e.g. “filled up 35 L at Shell for 2,520”."
        }
        let price = (liters > 0 && cost > 0) ? cost / liters : PriceService.price(for: v.fuelType, in: context)
        let log = FuelLog(vehicleId: v.id, vehicleName: v.name, fuelType: v.fuelType,
                          litersPurchased: liters, totalCostPHP: cost, pricePerLiter: price,
                          isFullTank: true, stationName: draft.stationName)
        context.insert(log)
        try? context.save()
        let station = draft.stationName.map { " at \($0)" } ?? ""
        return "Got it! Logged \(liters.clean) L\(station) for \(cost.phpString) (≈ PHP \(price.clean)/L) — full tank. ✅ Add the odometer in History → Fuel Log to unlock your real km/L."
    }

    /// "Show my monthly report" → a text summary (full report + share is in History).
    private func reportReply(_ text: String) -> String? {
        let q = text.lowercased()
        guard q.contains("report") && (q.contains("month") || q.contains("my ") || q.contains("fuel")) else { return nil }
        let r = FuelReport.monthly(for: Date(), trips: tripRecords, logs: fuelLogs)
        guard !r.isEmpty else {
            return "No trips yet this month. Calculate a trip and I'll start your \(r.monthLabel) report."
        }
        var s = "Your \(r.monthLabel): \(r.tripCount) trips, \(Int(r.totalDistanceKm)) km, \(r.totalSpentPHP.phpString) total (avg \(r.avgTripCostPHP.phpString)/trip, \(r.avgKmL.oneDecimal) km/L)."
        if let e = r.mostExpensive { s += "\nPriciest: \(e.title) (\(e.cost.phpString))." }
        return s + "\nOpen History → Report to view and share it. 📊"
    }

    /// "How accurate were my estimates?" → tracked-trip accuracy summary.
    private func accuracyReply(_ text: String) -> String? {
        let q = text.lowercased()
        guard q.contains("accurate") || q.contains("accuracy") ||
              (q.contains("estimate") && (q.contains("how") || q.contains("actual") || q.contains("real"))) else { return nil }
        let done = trackedTrips.filter { $0.isCompleted }
        guard !done.isEmpty else {
            return "You haven't tracked a trip yet. After a calculation, tap “Track This Trip” and drive — I'll compare the estimate to your actual distance."
        }
        let avg = done.reduce(0) { $0 + $1.accuracyPercent } / Double(done.count)
        let last = done.max { $0.endedAt < $1.endedAt }
        var s = "Across \(done.count) tracked trip\(done.count == 1 ? "" : "s"), your estimates averaged \(Int(avg.rounded()))% accurate."
        if let last { s += " Your last (\(last.origin) → \(last.destination)) was \(Int(last.accuracyPercent.rounded()))%." }
        return s
    }

    // MARK: - Feature 4 intents (driving score / tips / cost trend)

    private func defaultVehicle() -> VehicleProfile? { vehicles.first(where: \.isDefault) ?? vehicles.first }

    /// "How's my driving?" → the fuel-efficiency score + breakdown.
    private func drivingReply(_ text: String) -> String? {
        let q = text.lowercased()
        guard q.contains("my driving") || q.contains("driving score") || q.contains("fuel score")
            || (q.contains("how") && q.contains("driv")) || (q.contains("score") && q.contains("driv")) else { return nil }
        guard let v = defaultVehicle() else { return "Add a vehicle and take a few trips — then I can score your driving." }
        let trips = tripRecords.filter { $0.vehicleName == v.name }
        let s = DrivingScorer.score(for: v, trips: trips, trackedTrips: trackedTrips)
        return "Your \(v.name) scores \(s.total)/100 — \(s.label).\nSpeed \(s.speed)/30 · AC \(s.ac)/15 · Smoothness \(s.smoothness)/15 · Rush-hour \(s.rushHour)/20 · Maintenance \(s.maintenance)/20.\nSee Settings → Driving Insights for tips and a shareable card."
    }

    /// "How can I save fuel?" → up to 3 personalized tips.
    private func saveTipsReply(_ text: String) -> String? {
        let q = text.lowercased()
        guard (q.contains("save") && (q.contains("fuel") || q.contains("gas") || q.contains("petrol")))
            || q.contains("fuel saving") || q.contains("save money on gas")
            || (q.contains("tips") && (q.contains("fuel") || q.contains("driv"))) else { return nil }
        guard let v = defaultVehicle() else { return "Add a vehicle and take a few trips — I'll tailor fuel-saving tips to how you drive." }
        let trips = tripRecords.filter { $0.vehicleName == v.name }
        let cands = SuggestionEngine.candidates(
            vehicle: v, trips: trips, now: Date(),
            currentFuelPrice: PriceService.price(for: v.fuelType, in: context),
            unleaded91Price: PriceService.price(for: .unleaded91, in: context))
        guard !cands.isEmpty else {
            return "You're already driving efficiently — nice! Keep speeds near 80–100 km/h, ease off the aircon in slow traffic, and stay on top of PMS."
        }
        let top = SuggestionEngine.pick(cands, recentlyShownAt: [:], now: Date(), limit: 3)
        return "Here's how you could save on your \(v.name):\n" + top.map { "• \($0.detail)" }.joined(separator: "\n")
    }

    /// "Why is my fuel cost increasing?" → month-over-month analysis + likely causes.
    private func costTrendReply(_ text: String) -> String? {
        let q = text.lowercased()
        let mentionsCost = q.contains("cost") || q.contains("spend") || q.contains("bill") || q.contains("gas") || q.contains("fuel") || q.contains("mahal")
        let mentionsRise = q.contains("increas") || q.contains("higher") || q.contains("going up") || q.contains("more expensive") || q.contains("mahal") || q.contains("why")
        guard mentionsCost, mentionsRise else { return nil }
        let r = FuelReport.monthly(for: Date(), trips: tripRecords, logs: fuelLogs)
        guard !r.isEmpty else { return "Not enough trips this month yet to spot a trend. Calculate a few and ask again." }
        var s = "This month you've spent \(r.totalSpentPHP.phpString) across \(r.tripCount) trips."
        if let d = r.spendDeltaPHP, let p = r.spendDeltaPct {
            if d > 0 { s += " That's \(d.phpString) more than last month (+\(Int(p.rounded()))%)." }
            else if d < 0 { s += " That's actually \(abs(d).phpString) less than last month." }
            else { s += " About the same as last month." }
        }
        var causes: [String] = []
        if let v = defaultVehicle() {
            if v.maintenanceStatus == .overduePMS { causes.append("an overdue PMS (~15% more fuel)") }
            let month = tripRecords.filter { $0.vehicleName == v.name && Calendar.current.isDate($0.calculatedAt, equalTo: Date(), toGranularity: .month) }
            let rush = month.filter { $0.wasRushHour || $0.traffic == .heavy || $0.traffic == .standstill }.count
            if !month.isEmpty, rush * 2 >= month.count { causes.append("lots of rush-hour / heavy-traffic trips") }
        }
        if !causes.isEmpty { s += " Likely causes: " + causes.joined(separator: ", ") + "." }
        return s + " Pump prices also shift week to week — check the Prices tab."
    }

    // MARK: - Tank questions

    /// "How big is my Vios tank?" → tank capacity + full-tank cost. Resolves the
    /// vehicle from the text (owned vehicle → database model → default vehicle).
    private func tankSizeReply(_ text: String) -> String? {
        let q = text.lowercased()
        guard q.contains("tank") else { return nil }
        let cues = ["how big", "how large", "size", "capacity", "how many liter", "how many litre",
                    "how much fuel", "how much gas", "full tank", "liters", "litres", "gas tank", "fuel tank"]
        guard cues.contains(where: { q.contains($0) }) else { return nil }

        if let owned = ownedVehicle(in: text) {
            return tankBlurb(name: owned.name, tankL: owned.tankCapacityL, fuel: owned.fuelType)
        }
        if let entry = VehicleDatabase.find(text), !entry.isElectric {
            return tankBlurb(name: entry.displayName, tankL: entry.tankCapacityL, fuel: entry.fuelType)
        }
        if let v = vehicles.first(where: \.isDefault) ?? vehicles.first {
            return tankBlurb(name: v.name, tankL: v.tankCapacityL, fuel: v.fuelType)
        }
        return nil
    }

    private func tankBlurb(name: String, tankL: Double, fuel: FuelType) -> String {
        let price = PriceService.price(for: fuel, in: context)
        let cost = tankL * price
        return "The \(name) has a \(tankL.clean)-liter fuel tank. At current prices (PHP \(price.clean)/L), a full tank costs \(cost.phpString)."
    }

    /// "Will I make it to Baguio on one tank?" → compares the trip's fuel need to
    /// the vehicle's tank capacity (assuming a full tank at the start).
    private func oneTankReply(_ text: String) -> String? {
        let q = text.lowercased()
        let cues = ["one tank", "single tank", "1 tank", "on a full tank", "without refuel",
                    "without refueling", "without stopping", "without a stop", "enough fuel",
                    "enough gas", "run out of gas", "run out of fuel"]
        guard cues.contains(where: { q.contains($0) }) else { return nil }

        // Resolve the trip: a full parse of this message, else the last trip.
        let query = TripQueryParser.parse(text, vehicles: vehicles, personalPlaces: personalPlaces)
        let originName = query?.origin ?? lastQuery?.origin
        let destName = query?.destination ?? lastQuery?.destination
        guard let originName, let destName,
              let route = PlaceResolver.route(from: originName, to: destName, personalPlaces: personalPlaces) else {
            return "Tell me the trip too — like “Manila to Baguio on one tank” — and I'll check if you can make it without refueling."
        }

        guard let vehicle = query?.vehicleName.flatMap({ n in vehicles.first { $0.name == n } })
                ?? ownedVehicle(in: text)
                ?? vehicles.first(where: \.isDefault) ?? vehicles.first else {
            return "Add a vehicle first and I'll check if you can make the trip on one tank."
        }

        let profile = vehicle.drivingProfile
        let est = CalculationEngine.estimate(
            distanceKm: route.distanceKm, baseEfficiencyKmL: vehicle.efficiencyKmL,
            fuelPricePerLitre: PriceService.price(for: vehicle.fuelType, in: context),
            avgHighwaySpeedKmh: profile?.avgHighwaySpeedKmh ?? 90,
            avgCitySpeedKmh: profile?.avgCitySpeedKmh ?? 40,
            acInUse: profile?.usesACByDefault ?? true, roadType: profile?.defaultRoadType ?? .highway,
            ageYears: vehicle.ageYears(), maintenance: vehicle.maintenanceStatus)

        let needed = est.adjustedLitres
        let tank = vehicle.tankCapacityL
        let routeLabel = "\(originName.capitalized) to \(destName.capitalized)"
        if needed <= tank {
            let spare = tank - needed
            return "Your \(vehicle.name) needs ~\(needed.oneDecimal)L for \(routeLabel). Your \(tank.clean)L tank can handle it with ~\(spare.oneDecimal)L to spare. No refuel stop needed! ✅"
        } else {
            return "\(routeLabel) needs ~\(needed.oneDecimal)L, but your \(vehicle.name)'s tank only holds \(tank.clean)L. You'll need a refuel stop along the way. ⛽"
        }
    }

    // MARK: - Cross-island (multi-modal)

    /// If the message is a trip whose endpoints are on different islands, answer
    /// with the sea/air breakdown; else nil (a normal same-island trip).
    private func crossIslandReply(_ text: String) -> ChatMessage? {
        guard let query = TripQueryParser.parse(text, vehicles: vehicles, personalPlaces: personalPlaces) else { return nil }
        return interIslandMessage(for: query)
    }

    /// The multi-modal breakdown: land portion(s) + typical flight/ferry estimates
    /// + disclaimer. Returns nil when both endpoints are on the same landmass.
    private func interIslandMessage(for query: TripQuery) -> ChatMessage? {
        let o = query.origin, d = query.destination
        guard let islandO = IslandResolver.island(forPlace: o),
              let islandD = IslandResolver.island(forPlace: d),
              islandO != islandD else { return nil }

        let vehicle = vehicles.first { $0.name == query.vehicleName }
            ?? vehicles.first(where: \.isDefault) ?? vehicles.first
        let vehicleName = vehicle?.name ?? "your vehicle"

        var lines = ["🚢 \(o.capitalized) → \(d.capitalized) isn't a direct land route — \(d.capitalized) is on \(islandD), separate from \(o.capitalized) (\(islandO)).", ""]

        let hubO = IslandResolver.hub(for: islandO)
        let hubD = IslandResolver.hub(for: islandD)
        let fromHub = hubO ?? o.capitalized
        let toHub = hubD ?? d.capitalized

        // Land 1 — origin → departure hub (in the user's own vehicle).
        if let hubO, hubO.lowercased() != o.lowercased(),
           let land = PlaceResolver.route(from: o, to: hubO, personalPlaces: personalPlaces) {
            lines.append("🚗 Land — \(o.capitalized) → \(hubO): ≈\(land.distanceKm.oneDecimal) km, about \(landFuel(distanceKm: land.distanceKm, vehicle: vehicle)) fuel in \(vehicleName).")
        }

        // Inter-island — flight and/or ferry between hubs.
        if let flight = TravelRoutes.flight(from: fromHub, to: toHub) {
            lines.append("✈️ Flight — \(fromHub) → \(toHub): ~\(hoursText(flight.hours)), \(rangeText(flight.minPHP, flight.maxPHP)) (\(TravelRoutes.airlines.prefix(3).joined(separator: ", "))).")
        }
        if let ferry = TravelRoutes.ferry(from: fromHub, to: toHub) {
            var t = "🚢 Ferry — \(fromHub) → \(toHub): ~\(hoursText(ferry.hours)), \(rangeText(ferry.minPHP, ferry.maxPHP))"
            if let op = ferry.operatorName { t += " (\(op))" }
            if let car = ferry.withCarPHP { t += "; +PHP \(Int(car)) with a car (ro-ro)" }
            lines.append(t + ".")
        }
        if TravelRoutes.flight(from: fromHub, to: toHub) == nil && TravelRoutes.ferry(from: fromHub, to: toHub) == nil {
            lines.append("✈️/🚢 You'll need a flight or ferry between \(fromHub) and \(toHub) — check operator sites for schedules and fares.")
        }

        // Land 2 — arrival hub → destination (taxi/rental at destination).
        if let hubD, hubD.lowercased() != d.lowercased(),
           let land2 = PlaceResolver.route(from: hubD, to: d, personalPlaces: personalPlaces) {
            lines.append("🚗 Land — \(hubD) → \(d.capitalized): ≈\(land2.distanceKm.oneDecimal) km (taxi or rental at destination).")
        }

        lines.append("")
        lines.append(TravelRoutes.disclaimer)
        return ChatMessage(role: .aigos, text: lines.joined(separator: "\n"))
    }

    private func landFuel(distanceKm: Double, vehicle: VehicleProfile?) -> String {
        guard let vehicle else { return "—" }
        let est = CalculationEngine.estimate(
            distanceKm: distanceKm, baseEfficiencyKmL: vehicle.efficiencyKmL,
            fuelPricePerLitre: PriceService.price(for: vehicle.fuelType, in: context),
            avgHighwaySpeedKmh: 90, avgCitySpeedKmh: 40, acInUse: true, roadType: .highway)
        return est.estimatedCost.phpString
    }

    private func hoursText(_ h: Double) -> String {
        if h < 1 { return "\(Int((h * 60).rounded())) mins" }
        return h == h.rounded() ? "\(Int(h)) hrs" : "\(h.oneDecimal) hrs"
    }

    private func rangeText(_ lo: Double, _ hi: Double) -> String {
        "PHP \(Int(lo).formatted()) – \(Int(hi).formatted())"
    }

    private func estimate(for query: TripQuery) -> ChatMessage {
        // Cross-island endpoints can't be driven — hand off to the sea/air breakdown.
        if let multi = interIslandMessage(for: query) { return multi }
        // Personal shortcuts (Home/Office/…) resolve before the gazetteer.
        guard let route = PlaceResolver.route(from: query.origin, to: query.destination, personalPlaces: personalPlaces) else {
            return ChatMessage(role: .aigos, text: "I don't know that location yet. Try typing it in the calculator and pick from the suggestions.")
        }

        let vehicle = vehicles.first { $0.name == query.vehicleName }
            ?? vehicles.first(where: \.isDefault)
            ?? vehicles.first
        guard let vehicle else {
            return ChatMessage(role: .aigos, text: "Add a vehicle first and I can estimate this trip for you.")
        }

        let profile = vehicle.drivingProfile
        let roadType = profile?.defaultRoadType ?? .highway
        let rush = query.rushHour ?? false
        // Rush hour on city roads implies heavy traffic (Section 2 rule).
        let traffic = query.traffic ?? ((rush && roadType == .city) ? .heavy : .light)
        let acOn = query.acOn ?? (profile?.usesACByDefault ?? true)
        let load = query.load ?? .light

        let price = PriceService.price(for: vehicle.fuelType, in: context)
        let est = CalculationEngine.estimate(
            distanceKm: route.distanceKm,
            baseEfficiencyKmL: vehicle.efficiencyKmL,
            fuelPricePerLitre: price,
            avgHighwaySpeedKmh: profile?.avgHighwaySpeedKmh ?? 90,
            avgCitySpeedKmh: profile?.avgCitySpeedKmh ?? 40,
            acInUse: acOn,
            roadType: roadType,
            traffic: traffic,
            load: load,
            ageYears: vehicle.ageYears(),
            maintenance: vehicle.maintenanceStatus
        )

        var conditions: [String] = []
        if traffic != .light { conditions.append("\(traffic.label.lowercased()) traffic") }
        if load != .light { conditions.append(load.label.lowercased()) }
        if query.acOn == true { conditions.append("AC on") }
        if query.acOn == false { conditions.append("no AC") }
        if rush { conditions.append("rush hour") }
        let condText = conditions.isEmpty ? "" : " with \(conditions.joined(separator: ", "))"

        let draft = CalculatorDraft(
            origin: query.origin.capitalized,
            destination: query.destination.capitalized,
            distanceKm: route.distanceKm,
            vehicleId: vehicle.id,
            traffic: query.traffic ?? ((rush && roadType == .city) ? .heavy : nil),
            acOn: query.acOn,
            rushHour: query.rushHour,
            load: query.load
        )
        let text = "\(query.origin.capitalized) → \(query.destination.capitalized) is ≈\(route.distanceKm.oneDecimal) km\(condText). In your \(vehicle.name), that's roughly \(est.estimatedCost.phpString)."
        return ChatMessage(role: .aigos, text: text, result: ChatResult(draft: draft, costText: est.estimatedCost.phpString))
    }
}

// MARK: - Model

struct ChatResult: Equatable {
    let draft: CalculatorDraft
    let costText: String
}

struct ChatMessage: Identifiable {
    enum Role { case user, aigos }
    let id = UUID()
    let role: Role
    let text: String
    var result: ChatResult? = nil
    var vehicleSuggestion: VehicleAnswer? = nil
}

// MARK: - Bubble

private struct ChatBubble: View {
    let message: ChatMessage
    let onOpen: (CalculatorDraft) -> Void
    let onUseVehicle: (VehicleDraft) -> Void

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }

            VStack(alignment: .leading, spacing: Space.sm) {
                Text(message.text)
                    .rounded(15, weight: .medium)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                if let result = message.result {
                    Button {
                        onOpen(result.draft)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "bolt.fill")
                            Text("Open in Calculator")
                        }
                        .rounded(13, weight: .semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Space.md)
                        .padding(.vertical, 8)
                        .background(Color.aigosAmber, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                if let s = message.vehicleSuggestion {
                    vehicleButtons(for: s)
                }
            }
            .padding(Space.md)
            .background(message.role == .user ? Color.aigosAmber.opacity(0.9) : Color.white.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )

            if message.role == .aigos { Spacer(minLength: 40) }
        }
    }

    @ViewBuilder
    private func vehicleButtons(for s: VehicleAnswer) -> some View {
        if s.efficiencyKmL != nil {
            HStack(spacing: Space.sm) {
                pillButton("Use this efficiency", filled: true) { onUseVehicle(draft(from: s, useEfficiency: true)) }
                pillButton("Enter manually", filled: false) { onUseVehicle(draft(from: s, useEfficiency: false)) }
            }
        } else if s.offersAddVehicle {
            pillButton("Add a vehicle", filled: true) { onUseVehicle(draft(from: s, useEfficiency: false)) }
        }
    }

    private func pillButton(_ title: String, filled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .rounded(13, weight: .semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, Space.md)
                .padding(.vertical, 8)
                .background(filled ? Color.aigosAmber : Color.white.opacity(0.15), in: Capsule())
                .overlay(filled ? nil : Capsule().strokeBorder(Color.white.opacity(0.6), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private func draft(from s: VehicleAnswer, useEfficiency: Bool) -> VehicleDraft {
        VehicleDraft(
            name: s.suggestedName ?? "My Car",
            efficiencyKmL: useEfficiency ? s.efficiencyKmL : nil,
            tankCapacityL: s.tankCapacityL,
            fuelType: s.fuelType ?? .unleaded91,
            vehicleType: s.vehicleType ?? .car
        )
    }
}

#Preview {
    TalkToAigosView()
        .environment(AppState())
        .modelContainer(for: [
            VehicleProfile.self, DrivingProfile.self, TripRecord.self,
            SavedRoute.self, FuelPriceCache.self,
            PersonalPlace.self,
            TrackedTrip.self,
            FuelLog.self,
        ], inMemory: true)
}
