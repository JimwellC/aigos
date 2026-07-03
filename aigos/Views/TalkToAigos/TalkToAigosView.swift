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

struct TalkToAigosView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \VehicleProfile.createdAt) private var vehicles: [VehicleProfile]
    @Query private var personalPlaces: [PersonalPlace]

    @State private var messages: [ChatMessage] = []
    @State private var input = ""
    @State private var showingGate = false
    @State private var lastQuery: TripQuery?   // for conversational follow-ups

    private let suggestions = [
        "Manila to Batangas",
        "Pampanga to Manila with heavy traffic",
        "What's the km/L of a Vios?",
        "My car is a Honda City",
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
                }
                .padding(.horizontal, Space.screen)
                .padding(.vertical, Space.md)
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
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
        Haptics.tap(.light)
        input = ""
        let response = reply(to: trimmed)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            messages.append(ChatMessage(role: .user, text: trimmed))
            messages.append(response)
        }
    }

    private func reply(to text: String) -> ChatMessage {
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
        // Vehicle knowledge base — "what's the km/L of Vios?", "my car is Honda City".
        if let answer = VehicleDatabase.answer(for: text) {
            let suggestion = (answer.efficiencyKmL != nil || answer.offersAddVehicle) ? answer : nil
            return ChatMessage(role: .aigos, text: answer.text, vehicleSuggestion: suggestion)
        }
        return ChatMessage(
            role: .aigos,
            text: "I don't know that location yet. Try typing it in the calculator and pick from the suggestions."
        )
    }

    /// Match a vehicle named anywhere in the text (for "same trip in my truck").
    private func matchedVehicleName(in text: String) -> String? {
        let lower = text.lowercased()
        return vehicles.first { v in
            v.name.lowercased().split(separator: " ").contains { $0.count >= 3 && lower.contains($0) }
        }?.name
    }

    private func estimate(for query: TripQuery) -> ChatMessage {
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
            load: load
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
        let text = "\(query.origin.capitalized) → \(query.destination.capitalized) is about \(route.distanceKm.oneDecimal) km\(condText). In your \(vehicle.name), that's roughly \(est.estimatedCost.phpString)."
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
        ], inMemory: true)
}
