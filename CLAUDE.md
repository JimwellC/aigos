# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

**Sprints 1–3 built.** The `aigos.xcodeproj` app exists and builds warning-clean (Swift 6, iOS 17+); `aigos_architecture.pdf` remains the source-of-truth spec. Done: 5-tab shell with a custom amber tab bar, SwiftData models, physics `CalculationEngine`, editable prices, trip history with month-over-month comparison, saved routes with one-tap recalc, the self-learning `ProfileLearningEngine`, first-launch onboarding, and "Talk to aigos" natural-language trip queries (`TalkToAigosView`). The whole UI follows the glassmorphism design system (see `UI_GUIDELINES.md` / `skills/swiftui-design.md`) built in `Support/DesignSystem.swift`. Not yet built: real OSRM routing (still a gazetteer prototype behind `RouteResolver`), a unit-test target, and real app-icon/mascot art.

**Apple Intelligence reality check:** this Xcode 16.4 / iOS 18.5 SDK does **not** ship the `FoundationModels` framework (Apple's on-device LLM API lands in a later SDK), so the spec's `LanguageModelSession.isSupported` gate can't compile here. `AIAvailability` puts the real system-model path behind `#if canImport(FoundationModels)` (excluded now, lights up when built against that SDK on an A17 Pro+ device); NL understanding today runs through `TripQueryParser`, a deterministic offline parser that works on every device. Don't add `import FoundationModels` outside that guard until the SDK provides it.

Extract the PDF text if you need to re-read the spec:

```bash
pip3 install --break-system-packages pypdf
python3 -c "from pypdf import PdfReader; print('\n'.join((p.extract_text() or '') for p in PdfReader('aigos_architecture.pdf').pages))"
```

## What aigos is

An offline, privacy-first iOS fuel-trip cost calculator for Filipino roads. Native SwiftUI (Swift 6, iOS 17+), one-time paid App Store app, zero backend, built solo. It follows the "Tarsi" playbook: ship in days, no login, no cloud, no ongoing cost, solve a Filipino-specific problem.

## Non-negotiable constraints (locked by the spec — do not re-litigate)

- **Offline-first, zero backend.** Every core feature must work with no internet. No cloud, no servers, no iCloud sync, no analytics/tracking SDKs. The *only* permitted network call is an optional v1.1 remote-JSON fuel-price fetch, which must fall back to cached values offline.
- **iOS only.** SwiftUI + Swift 6, minimum iOS 17. No React Native, no cross-platform, no Android. (The developer knows React Native but is new to SwiftUI — write complete, copy-pasteable SwiftUI, not snippets or pseudocode.)
- **SwiftData for all persistence.** No CoreData. No `UserDefaults` for complex objects. Use the default `ModelContainer`.
- **The spec is final.** Every decision in `aigos_architecture.pdf` (Section 6 decision log) is locked. Don't re-ask answered questions or propose alternatives unless the developer explicitly reopens a decision.
- **Currency renders as `PHP` prefix** (e.g. `PHP 261.43`), never the ₱ glyph — it renders inconsistently across devices.
- **App name is `aigos`** — always lowercase, never capitalized.
- **Primary accent color** is amber `#E9A84C`.

## Architecture

Flat `TabView` with 5 tabs (no deep `NavigationStack` hierarchies — every feature is one tap from anywhere): **Calculate** (`car.fill`, default) · **History** (`clock.fill`) · **Saved** (`star.fill`) · **Prices** (`fuelpump.fill`) · **Settings** (`gearshape.fill`).

Planned structure (Section 17 of the spec): `App/` (`aigosApp.swift` @main + ModelContainer, `ContentView.swift` TabView), `Models/` (SwiftData @Model entities + `Enums.swift`), `Views/` (one folder per tab, plus `TalkToAigos/` and `Onboarding/`), `Services/` (`CalculationEngine`, `OSRMService`, `PriceService`), `Resources/` (`FuelPrices.json`, bundled PH OSRM road data), `Assets.xcassets`.

### SwiftData models (Section 9)

`VehicleProfile` (has a `@Relationship` to a per-vehicle `DrivingProfile`), `TripRecord` (auto-saved on every calculation as a full breakdown snapshot), `DrivingProfile` (per-vehicle, self-learning), `SavedRoute`, `FuelPriceCache` (one row per fuel type). Enums: `VehicleType`, `FuelType {ron91, ron95, ron97, diesel}`, `RoadType {highway, city, mountain}`, `ProfileConfidence {new, building, confident}`. Seed `FuelPriceCache` on first launch from `FuelPrices.json`.

### Core calculation (Section 8 — implement exactly)

Physics-based, not simple multipliers. The result screen must show a full breakdown, not just a number — this transparency is a core product principle.

```
adjustmentMultiplier = speedFactor * acFactor * roadFactor
adjustedEfficiencyKmL = baseEfficiencyKmL / adjustmentMultiplier
litresNeeded = distanceKm / adjustedEfficiencyKmL
estimatedCost = litresNeeded * fuelPricePerLitre
```

- `speedFactor` — lookup table (Section 14E): <60 km/h → 1.18, 60–80 → 1.08, 80–100 → 1.00 (optimal), 100–120 → 1.13, >120 → 1.22.
- `acFactor` — `1.12` when AC on, else `1.0`.
- `roadFactor` — highway `1.00`, city `1.20`, mountain `1.35`.
- Settings offers an L/100km toggle: convert `kmL = 100.0 / l100kmValue` before feeding the formula.

### Smart Driving Profile (Section 14 — the key differentiator)

Per-vehicle, set via the "Talk to aigos" hybrid interview (mascot chat bubble + tap-to-answer buttons, no keyboard) before each trip, and self-corrects from trip history. After each trip, `ProfileLearningEngine.updateProfile` updates a rolling average (recent 10 trips weighted most) and bumps `confidenceLevel` by trip count (0–4 new / 5–14 building / 15+ confident). Remember the last answers per vehicle and offer a one-tap "Same as last time?" confirm.

### Talk to aigos / Apple Intelligence gate (Section 13)

"Talk to aigos" (`Views/TalkToAigos/`) answers plain-English trip queries. Entry point is the chat button in `CalculateView`'s header. Pipeline: `TripQueryParser.parse` extracts origin/destination/vehicle (reusing the gazetteer via `GazetteerRouteResolver.lookup`/`isPlace`/`isPlaceKey`) → `CalculationEngine` estimates → the reply offers "Open in Calculator", which hands a `CalculatorDraft` to `CalculateView` for the real (saved + learning) calc. `AIAvailability` is the gate (`#if canImport(FoundationModels)` for the real system model, else offline parser) and drives the header badge + `AIGateView`. **The core app — and Talk to aigos — must work 100% without Apple Intelligence on any iOS 17+ device** (the parser is deterministic and offline); AI only enhances understanding when present.

### Routing (highest technical risk — prototype first)

OSRM + a bundled Philippine OpenStreetMap dataset, fully offline, zero per-call cost. Target the compressed bundle under 100MB; if it exceeds the limit, fall back to manual distance entry (or App Store on-demand resources). Prototype and de-risk this before building anything else in Sprint 1.

## Build & run

Build/run via **Xcode 16+** (required for SwiftUI + Foundation Models), or headlessly:

```bash
xcodebuild -scheme aigos -destination 'platform=iOS Simulator,name=iPhone 16' build
xcrun simctl install "iPhone 16" \
  build/DerivedData/Build/Products/Debug-iphonesimulator/aigos.app
xcrun simctl launch "iPhone 16" com.aigos.app
```

The project uses Xcode 16 **synchronized folder groups** (`PBXFileSystemSynchronizedRootGroup`) — new files under `aigos/` are picked up automatically; no need to edit `project.pbxproj` when adding sources.

**DEBUG launch args** (see `Support/DebugSupport.swift`) drive the app headlessly for screenshots/QA — the custom tab bar can't be tapped from `simctl`:

```bash
# seed a demo garage + trips across two months + a saved route, open a given tab:
xcrun simctl launch "iPhone 16" com.aigos.app -seedDemo -tab history
#   -tab: calculate|history|saved|prices|settings   (calculate auto-runs a sample estimate)
```

No unit-test target exists yet. Pure logic (`CalculationEngine`, `ProfileLearningEngine.rollingAvg`) is currently checked with standalone `swift` scripts against the spec's worked examples; add an `aigosTests` target when hardening.

## Roadmap (Section 20)

- **Sprint 1 (default start):** Xcode + SwiftData `ModelContainer` setup, TabView skeleton, the four SwiftData models, an **OSRM prototype** (do this first), `CalculateView` (origin/destination input, vehicle picker, result card), `CalculationEngine`, editable `PricesView`. *Done when:* a user can pick a vehicle, enter origin + destination, tap calculate, and see a PHP fuel cost.
- **Sprint 2:** auto-save trips → `HistoryView` with month-over-month comparison, `SavedRoutesView`, `SettingsView`, 3-screen onboarding, app icon + jeepney mascot assets.
- **Sprint 3:** Apple Intelligence / `TalkToAigosView`, `AIGateView`, App Store assets + submission.

When starting fresh, default to Sprint 1 unless told otherwise. Keep scope tight — feature creep is the named enemy; ship imperfect and iterate.

## Skills & References
- UI/UX design system: see UI_GUIDELINES.md
- SwiftUI patterns: see skills/swiftui-design.md