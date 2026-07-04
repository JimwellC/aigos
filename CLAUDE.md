# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

**Sprints 1–3 built.** The `aigos.xcodeproj` app exists and builds warning-clean (Swift 6, iOS 17+); `aigos_architecture.pdf` remains the source-of-truth spec. Real jeepney mascot art is in place — **two** mascots, both delivered as source PNGs with a transparency-checker baked in as opaque pixels (strip it to real alpha with a scratchpad PIL/AppKit pass, never ship the raw checker): (1) `mascot.png` → front-facing badge in `Mascot.imageset`, used via `MascotView(imageName:"Mascot")` for the splash (168), Calculate header (44), Talk avatar (44), onboarding chat bubble (40); (2) `mascot_wave.png` → a **waving** jeepney (checker stripped + cropped) in `MascotWave.imageset`, used for the onboarding welcome hero and the subtle per-tab background watermark. `MascotView` takes `imageName` (default `"Mascot"`), plus `floatDistance`/`floatDuration` for the bob. The **app icon** is regenerated (scratchpad PIL) from `mascot_wave.png` — oversized 115%, bled off the bottom-right, over a diagonal `#F5C97A→#C4793A` amber gradient, opaque 1024² no-alpha. The **wave background watermark** rides in `AigosBackground`'s opt-in `mascotPeek: CGSize?` param (rendered inside the orb `.overlay` so it can't inflate layout — same rule as the bokeh orbs), 300pt @ opacity 0.20, `.bottomTrailing`, on all 5 tab roots only (Calc 60/-70, History 65/-80, Saved 55/-75, Prices 60/-70, Settings 60/-80). `MascotEmptyState` is **text-only** (the tab watermark supplies its mascot — don't re-add a peek there or it doubles). Onboarding is now 4 steps: **0 = welcome hero** (large centered `Mascot`, 220pt, ±8pt/2.5s float), 1 = add vehicle, 2 = driving, 3 = prices; the progress bar is hidden on step 0. Don't reintroduce the `bus.fill` placeholder. Done: 5-tab shell with a custom **floating pill** tab bar (`AigosTabBar` — icon-only, amber `matchedGeometryEffect` indicator), SwiftData models, physics `CalculationEngine`, editable prices (tap-to-edit inline rows), trip history with month-over-month comparison + stats, saved routes with one-tap recalc, the self-learning `ProfileLearningEngine`, first-launch onboarding, animated splash + static launch screen, and "Talk to aigos" natural-language trip queries with an offline **vehicle knowledge base** (`TalkToAigosView` + `VehicleDatabaseService`). The whole UI follows the glassmorphism design system (see `UI_GUIDELINES.md` / `skills/swiftui-design.md`) built in `Support/DesignSystem.swift`. Reusable **native** animation primitives live in `Support/Animations.swift` (`staggeredAppear(index:)`, `PressableStyle`, `Shake`); count-ups use `contentTransition(.numericText)` driven by a spring. No third-party animation libraries — and note `Animatable.animatableData` can't be a stored property on a `@MainActor` `View` under Swift 6, so use `contentTransition`/`GeometryEffect` instead. An `aigosTests` unit-test target covers the pure logic (**111 cases**, all passing). Real app-icon + mascot art are done. Distances are gazetteer haversine×1.3 estimates offline, upgraded to precise `MKDirections` road distance when the optional map picker is used online (see the map/privacy notes below).

**Talk to aigos (v1.0 = offline parser only):** NL understanding runs through `TripQueryParser`, a deterministic offline parser that works on every device. Per the v1.0 product decision, the UI is **provider-neutral** — no "Apple Intelligence" or device-requirement wording anywhere (badge reads "On-device · works offline"). A seam for a real on-device system model is kept behind `#if canImport(FoundationModels)` in `AIAvailability` for v1.1 (this Xcode 16.4 / iOS 18.5 SDK doesn't ship the framework, so it's excluded now). Don't reintroduce Apple Intelligence framing in the UI or add `import FoundationModels` outside that guard.

**Routing (v1.0 = autocomplete-validated places → estimated distance):** places come from `GazetteerData.entries` (rich `GazetteerEntry`: title, province subtitle, coordinate, aliases like "BGC"/"EDSA"/"QC"). `GazetteerRouteResolver` derives an `index` (key + every alias → entry) and resolves via `lookup`/`entry(for:)`. `PlaceSearch.suggestions(...)` powers the `PlaceField` autocomplete (personal places first, then gazetteer, max 5); `PlaceSearch.exactKey(...)` is the validation gate (random text like "J" → nil). **`CalculateView` requires both origin AND destination selected from the dropdown** (`originKey`/`destinationKey` non-nil) before Calculate enables; distance is derived from the two picked places (haversine×1.3), OR the precise `MKDirections` road distance when a place is set via the map picker while online. `PlaceResolver` still resolves personal aliases before the gazetteer for `TripQueryParser`/Talk, and now also decodes map-picked `@pin:lat,lon` selection keys. **Personal places are now map-pinned:** `PersonalPlace` stores a precise `latitude`/`longitude` + reverse-geocoded `displayName` (legacy `gazetteerKey` still honored as a fallback), set via the center-pin `PlaceMapPicker` (Settings → Edit Place — the old city list is gone). `PlaceResolver.point` returns a personal place's exact `geoPoint` first, so using "Home"/"Office" in the calculator uses precise coordinates. Offline-safe: if reverse geocode fails the coordinate still saves and `mappedLabel` shows `lat, lon`. Manual free-text distance entry was removed in favour of validated place selection. The optional `LocationPickerView` (MapKit) lets users search/drop a pin; it's additive — the gazetteer estimate is the offline fallback. The gazetteer is built with `Dictionary(uniquingKeysWith:)` so a duplicate key can't crash launch; `lookup` is deterministic (longest contained key).

## Where we left off (session end · 2026-07-04, session 2)

**State:** builds warning-clean (Swift 6, iOS 17+), **111 tests passing**, everything committed + pushed to `github.com/JimwellC/aigos` (private, `main`; latest `616f0b1`). Everything below is DONE and on `main`.

**Shipped session 2 — Fastlane + mascot system:**
- **Fastlane** (installed via Homebrew — vendors its own Ruby; system Ruby is 2.6, too old). `fastlane/` has `Appfile` (bundle `com.aigos.app`, team `MWJJ994KSX`), `Fastfile` lanes — `test` / `build` / `beta` (TestFlight) / `release` (App Store, no auto-submit) / `metadata` / `verify` (read-only ASC auth check) — authed by an **App Store Connect API key** (`fastlane/.env`, gitignored; template in `.env.template`). Build number = git commit count injected at build time (`CURRENT_PROJECT_VERSION` via xcargs), so the tracked project stays clean. `deliver` metadata is wired from `docs/app-store/` into `fastlane/metadata/`. `fastlane/SETUP.md` is the human guide; `fastlane/README.md` is auto-generated (fastlane rewrites it each run). Analytics opted out (`opt_out_usage`).
- **App Store Connect:** the app record for `com.aigos.app` exists; `fastlane metadata` has pushed the full listing (name/subtitle/description/keywords/promo/release notes/review notes). **Temporary placeholders still live in the listing** and must be replaced before submit: `support_url` = a Facebook page, `privacy_url` = an `app.notion.com` link (**verify it opens without login — Apple rejects gated privacy URLs; publish as `notion.site`**), review `phone_number` = a real number is set. `.gitignore` hardened for secrets (`.env`, `**/*.p8`, `fastlane/keys/`); no secret has ever been committed. `aigos_architecture.pdf` is now untracked (kept on disk, gitignored).
- **Mascot system** (see Project state above): `mascot_wave.png` + `MascotWave.imageset`, onboarding welcome hero, per-tab background watermark, text-only empty states, and the app icon redesigned from the waving mascot.

**Shipped this session:** full visual system (glassmorphism, richer 3-stop gradient + defined golden bokeh, floating pill tab bar, premium typography, global `pillStyle`, white-icon contrast audit); real jeepney mascot art (app icon 1024² no-alpha, launch image, `MascotView`); animated splash → app; onboarding layout fix (the oversized SF-symbol texture was inflating the ZStack width — held in a `Color.clear`/`.clipped()`) + wrapping flow pills; PH fuel-grade rename (`FuelType` = unleaded91/premium95/premium97/diesel/premiumDiesel/eGasoline) with `FuelType.detect(in:)`; Calculate loading animation → **result bottom sheet** (`ResultSheet`); **`DrivingSheet`** (closable How-you'll-drive); History labeled stat pills (hero total → stats → delta); **vehicle knowledge base** (`VehicleDatabaseService` + `VehicleDatabase.json`, 65 vehicles, fuzzy/Tier-2/age/fuel) wired into Talk with `[Use this efficiency]`/`[Enter manually]` → `AddVehicleView` prefill; Prices tap-to-edit inline rows; **MapKit location picker + route mini-map** (`LocationPickerView`, `RoutePreview`, `MKDirections`).

**Submission P0 (code side) — DONE:** `PrivacyInfo.xcprivacy` (no data collected; Precise Location = App Functionality, not linked, not tracking; UserDefaults `CA92.1`), `ITSAppUsesNonExemptEncryption = NO`, `NSLocationWhenInUseUsageDescription`, AC "Sometimes" real 1.06 factor, "≈" prefix on all distances.

**Next when you return:**
1. **Signing — DONE:** `DEVELOPMENT_TEAM = MWJJ994KSX`, automatic signing. Archive/upload is unblocked (`fastlane beta`/`release` use `-allowProvisioningUpdates`).
2. **Replace the 3 temporary listing placeholders** (support URL, public privacy URL, phone if needed) then re-run `fastlane metadata`. Host `docs/app-store/privacy-policy.md` at a login-free URL first.
3. **Test on a physical iPhone** — the Talk → "Use this efficiency" → `AddVehicleView` handoff (note the 0.35s double-sheet delay), map-picker confirm round-trip, keyboard toolbars, haptics; and eyeball the new onboarding welcome hero + tab watermark + app icon on-device.
4. **App Store Connect (web UI, not fastlane-managed):** set category (**Navigation**), age rating **4+**, price tier, and the App Privacy nutrition labels — must MIRROR `PrivacyInfo.xcprivacy` (Location → App Functionality, not linked, not tracking).
5. **Build + submit:** `fastlane beta` (TestFlight smoke-test) → `fastlane release` (pushes binary + metadata; does NOT auto-submit — review the draft, then submit in ASC or flip `submit_for_review`).
6. **Marketing screenshots** (6.7") — the screenshots lane isn't wired yet (`skip_screenshots(true)`); drop PNGs in `fastlane/screenshots/en-US/`. Listing copy, 5 captions, privacy text, and review notes live in **`docs/app-store/`**.

**Known caveats / v1.1 backlog:** map picker wants on-device tap verification; Talk age question is per-message (no model memory of the previous vehicle); vehicle-DB year-variant logic is untested against data (data has engine/fuel variants, not year); a dedicated offline static-map screen was folded into the picker (gazetteer dots + gazetteer search fallback); Apple-Intelligence/`FoundationModels` seam still compiled out (needs an iOS 26 SDK); optional remote price fetch not built.

**DEBUG launch args (headless screenshots/QA — see `DebugSupport`):** `-seedDemo` (wipe + seed a garage/trips/route, marks onboarded), `-seedEmpty` (**onboarded but no data** — drives empty-state screens; needed because `-seedDemo` always populates), `-tab <calculate|history|saved|prices|settings>`, `-autoCalc`, `-lowFuel`, `-talk` / `-talkQuery "…"` / `-talkQuery2 "…"`, `-onboarding` (skips splash → onboarding; only works when NOT onboarded, i.e. fresh install or after `uninstall`), `-onboardingStep N` (**0 = welcome hero, 1 = add vehicle, 2 = driving, 3 = prices**), `-driving`, `-mapPicker`, `-routePreview`, `-editPrice`, `-editPlace` (auto-open the Edit Place editor for the first personal place) / `-placeMap` (with `-editPlace`, also auto-present the map picker), `-searchDemo "…"`. There is **no** `-hasOnboarded` arg. Screenshots via `xcrun simctl` (the custom UI can't be tapped headlessly, so these args drive it); after `-tab`, terminate + sleep ≥2.5s before relaunch or it races to the previous instance.

Extract the PDF text if you need to re-read the spec:

```bash
pip3 install --break-system-packages pypdf
python3 -c "from pypdf import PdfReader; print('\n'.join((p.extract_text() or '') for p in PdfReader('aigos_architecture.pdf').pages))"
```

## What aigos is

An offline, privacy-first iOS fuel-trip cost calculator for Filipino roads. Native SwiftUI (Swift 6, iOS 17+), one-time paid App Store app, zero backend, built solo. It follows the "Tarsi" playbook: ship in days, no login, no cloud, no ongoing cost, solve a Filipino-specific problem.

## Non-negotiable constraints (locked by the spec — do not re-litigate)

- **Offline-first, zero backend.** Every *core* feature must work with no internet. No cloud, no servers, no iCloud sync, no analytics/tracking SDKs. Two network exceptions are now allowed: (1) an optional v1.1 remote-JSON fuel-price fetch that falls back to cached values; (2) the **optional MapKit location picker** (`LocationPickerView`) — `MKLocalSearch`, `MKDirections` road distance, tiles, reverse geocoding, and one-shot `CLLocation`. This is an *enhancement*: the app still fully works offline via the gazetteer autocomplete + haversine estimate. When adding features, keep the offline path intact and gate anything networked behind graceful fallback. Note this deviates from the original "only fuel-price" rule — it was an explicit product decision.

- **Privacy (locked declaration).** `NSPrivacyTracking = false`. The app collects **no** data on its own servers (there are none). The map picker requests **precise location only when the user taps the map button**, uses it purely on-device to set a starting point, and never stores/transmits/links it. `PrivacyInfo.xcprivacy` declares Precise Location as `AppFunctionality`, **not linked to identity, not used for tracking**; plus the one required-reason API (`UserDefaults`, `CA92.1`). App Store Connect nutrition labels must mirror this: Location → App Functionality, not linked, not tracking. Do not add data collection, tracking SDKs, or an ATT prompt.
- **iOS only.** SwiftUI + Swift 6, minimum iOS 17. No React Native, no cross-platform, no Android. (The developer knows React Native but is new to SwiftUI — write complete, copy-pasteable SwiftUI, not snippets or pseudocode.)
- **SwiftData for all persistence.** No CoreData. No `UserDefaults` for complex objects. Use the default `ModelContainer`.
- **The spec is final.** Every decision in `aigos_architecture.pdf` (Section 6 decision log) is locked. Don't re-ask answered questions or propose alternatives unless the developer explicitly reopens a decision.
- **Currency renders as `PHP` prefix** (e.g. `PHP 261.43`), never the ₱ glyph — it renders inconsistently across devices.
- **App name is `aigos`** — always lowercase, never capitalized.
- **Primary accent color** is amber `#E9A84C`.

## Architecture

Launch flow: the static `LaunchScreen.storyboard` (a composed `LaunchImage` — gradient + mascot + wordmark) shows instantly, then `RootView` (in `aigosApp.swift`) shows the animated `SplashView` and fades into `ContentView`. Splash auto-advances (~1.8s) for returning users; first-launch shows a "Get Started" CTA → onboarding (whose own welcome screen was removed to avoid duplication).

Flat `TabView` with 5 tabs (no deep `NavigationStack` hierarchies — every feature is one tap from anywhere): **Calculate** (`car.fill`, default) · **History** (`clock.fill`) · **Saved** (`star.fill`) · **Prices** (`fuelpump.fill`) · **Settings** (`gearshape.fill`).

Planned structure (Section 17 of the spec): `App/` (`aigosApp.swift` @main + ModelContainer, `ContentView.swift` TabView), `Models/` (SwiftData @Model entities + `Enums.swift`), `Views/` (one folder per tab, plus `TalkToAigos/` and `Onboarding/`), `Services/` (`CalculationEngine`, `OSRMService`, `PriceService`), `Resources/` (`FuelPrices.json`, bundled PH OSRM road data), `Assets.xcassets`.

### SwiftData models (Section 9)

`VehicleProfile` (has a `@Relationship` to a per-vehicle `DrivingProfile`), `TripRecord` (auto-saved on every calculation as a full breakdown snapshot), `DrivingProfile` (per-vehicle, self-learning), `SavedRoute`, `FuelPriceCache` (one row per fuel type), `PersonalPlace` (named shortcut `name`→`gazetteerKey`, e.g. "Home"→"makati"). Enums: `VehicleType`, `FuelType {unleaded91, premium95, premium97, diesel, premiumDiesel, eGasoline}` (PH pump names — raw values are the `FuelPrices.json` keys; `FuelType.detect(in:)` maps old RON + new names for Talk), `RoadType {highway, city, mountain, mixed}`, `TrafficCondition`, `VehicleLoad`, `FuelLevel`, `ACUsage {always, sometimes, off}` (UI-only 3-state AC; `.isOn` drives the binary estimate), `ProfileConfidence {new, building, confident}`. Seed `FuelPriceCache` (from `FuelPrices.json`) and empty `PersonalPlace` shortcuts (Home/Office/School) on first launch via `AppSeeder`. **Any new @Model must be added to the schema in `aigosApp` AND every view's `#Preview` `.modelContainer(for:)` list.**

### Core calculation (Section 8 — implement exactly)

Physics-based, not simple multipliers. The result screen must show a full breakdown, not just a number — this transparency is a core product principle.

**Driving options:** the "How you'll drive" card is a tappable summary row (truncated one-liner like "Highway · 110 km/h · AC on · Heavy traffic") that opens `DrivingSheet` — a `.large` bottom sheet (drag indicator + X + Done, `presentationBackground { AigosBackground() }`) with amber-pill sections for Speed (Highway/City buckets), Air conditioning, Road type, Traffic (+ rush-hour toggle), Passengers & load, Fuel level. Bindings apply live, so the summary updates on dismiss. (The old inline expand — which had no way to collapse — is gone.)

**Result presentation:** the Calculate screen stays clean (vehicle · route · driving profile only). Tapping Calculate shows a loading state (`isCalculating` → spinner + "Calculating…" with an intensified amber glow, light haptic on start), computes immediately, then after a **minimum 1.2s** reveals the result as a bottom **`.sheet`** (`ResultSheet`, `.presentationDetents([.large])`, drag indicator, `.presentationBackground { AigosBackground() }`, medium haptic on reveal). `ResultSheet` = route header ("Origin → Destination" + vehicle name) → `ResultCard` receipt (owns its own 0→final count-up via `heroCost`) → "Save this route" (secondary) + "Done" (primary). Swipe-down dismisses back to the form to adjust. `startCalculate()` orchestrates loading+delay; `performCalculation()` computes/persists/learns. `ResultCard` is never rendered inline anymore.

```
adjustmentMultiplier = speedFactor * acFactor * roadFactor * trafficFactor * loadFactor
adjustedEfficiencyKmL = baseEfficiencyKmL / adjustmentMultiplier
litresNeeded = distanceKm / adjustedEfficiencyKmL
estimatedCost = litresNeeded * fuelPricePerLitre
```

- `speedFactor` — lookup table (Section 14E): <60 km/h → 1.18, 60–80 → 1.08, 80–100 → 1.00 (optimal), 100–120 → 1.13, >120 → 1.22.
- `acFactor` — `1.12` when AC on, else `1.0`.
- `roadFactor` — highway `1.00`, city `1.20`, mountain `1.35`.
- `trafficFactor` (`TrafficCondition`) — light `1.00`, moderate `1.08`, heavy `1.25`, standstill `1.35`. Rush hour + city road auto-suggests heavy.
- `loadFactor` (`VehicleLoad`) — driver-only `1.00`, 3–4 pax `1.05`, full `1.10`, cargo `1.15`.
- `traffic`/`load` default to `.light` on `estimate(...)`, so any caller that omits them is unaffected. All factors are shown as separate rows in `ResultCard`.
- Low-fuel warning: pass `availableFuelLitres` (= `FuelLevel.fraction × VehicleType.typicalTankLiters`); `FuelEstimate.needsRefuel` is true when `adjustedLitres` exceeds it. Doesn't affect cost.
- Settings offers an L/100km toggle: convert `kmL = 100.0 / l100kmValue` before feeding the formula.

### Smart Driving Profile (Section 14 — the key differentiator)

Per-vehicle, set via the "Talk to aigos" hybrid interview (mascot chat bubble + tap-to-answer buttons, no keyboard) before each trip, and self-corrects from trip history. After each trip, `ProfileLearningEngine.updateProfile` updates a rolling average (recent 10 trips weighted most) and bumps `confidenceLevel` by trip count (0–4 new / 5–14 building / 15+ confident). Remember the last answers per vehicle and offer a one-tap "Same as last time?" confirm.

### Talk to aigos / Apple Intelligence gate (Section 13)

"Talk to aigos" (`Views/TalkToAigos/`) answers plain-English trip queries. Entry point is the chat button in `CalculateView`'s header. Pipeline: `TripQueryParser.parse` extracts origin/destination/vehicle (reusing the gazetteer via `GazetteerRouteResolver.lookup`/`isPlace`/`isPlaceKey`) → `CalculationEngine` estimates → the reply offers "Open in Calculator", which hands a `CalculatorDraft` to `CalculateView` for the real (saved + learning) calc. `AIAvailability` is the gate (`#if canImport(FoundationModels)` for the real system model, else offline parser) and drives the header badge + `AIGateView`. **The core app — and Talk to aigos — must work 100% without Apple Intelligence on any iOS 17+ device** (the parser is deterministic and offline); AI only enhances understanding when present.

**Vehicle knowledge base:** `VehicleDatabaseService` (loads bundled `Resources/VehicleDatabase.json` — 65 top PH cars + motorcycles with real-world km/L, fuel, type, category) answers "what's the km/L of a Vios?" style questions offline. `VehicleDatabase.answer(for:) -> VehicleAnswer?` classifies the message (Premium-95 advice, how-to-measure explainer, age/engine-wear ×0.85, fuel-type, exact/fuzzy model lookup with Levenshtein typo tolerance + variant disambiguation, or Tier-2 category range fallback) and returns nil when it isn't a vehicle question. Talk checks it **after** trip/follow-up parsing (so "Manila→Batangas in my Vios" stays a trip). A found model renders **[Use this efficiency]** / **[Enter manually]** buttons → `appState.addVehicle(VehicleDraft)` → `CalculateView` opens `AddVehicleView` prefilled (efficiency converted to the user's unit). Covered by `VehicleDatabaseTests` (13 cases).

**Conversational follow-ups:** the chat keeps `lastQuery`. A message with no route of its own but with condition hints / a follow-up phrase / a vehicle change (e.g. "same trip but it's EDSA on a Friday", "what about with cargo", "in my truck") is routed through `FollowUp.merge` (in `Services/FollowUp.swift`), which layers the new `TripHints` (from `TripQueryParser.hints(from:)`) onto the previous trip — unspecified fields keep their prior value, so conditions accumulate.

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

Tests (36 cases covering the pure logic — `CalculationEngine`, `ProfileLearningEngine`, `TripQueryParser`, `GazetteerRouteResolver`, formatting, `MonthGroup`):

```bash
xcodebuild -scheme aigos -destination 'platform=iOS Simulator,name=iPhone 16' test
# single test:
xcodebuild -scheme aigos -destination 'platform=iOS Simulator,name=iPhone 16' \
  test -only-testing:aigosTests/CalculationEngineTests/testSpecWorkedExample
```

The project uses Xcode 16 **synchronized folder groups** (`PBXFileSystemSynchronizedRootGroup`) — new files under `aigos/` (app) and `aigosTests/` (tests) are picked up automatically; no need to edit `project.pbxproj` when adding sources. Tests use `@testable import aigos`, so app types can stay `internal`.

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